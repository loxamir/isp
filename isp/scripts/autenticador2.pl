#!/usr/bin/perl
	use POSIX;
	use threads;
	use threads::shared;
	use DBI;
	use strict;
	use Time::Piece;
	use Data::Validate::IP qw(is_ipv4 is_ipv6);

	use vars qw(%RAD_REQUEST %RAD_REPLY %RAD_CHECK);

	my $data = POSIX::strftime("%d/%m/%Y-%k:%M:%S",localtime);
	my $dia = POSIX::strftime("%d/%m/%Y",localtime);
	my $hora = POSIX::strftime("%k:%M:%S",localtime);
	my $format = '%d/%m/%Y';

	use constant    RLM_MODULE_REJECT=>    0;#  /* immediately reject the request */
	use constant    RLM_MODULE_FAIL=>      1;#  /* module failed, don't reply */
	use constant    RLM_MODULE_OK=>        2;#  /* the module is OK, continue */
	use constant    RLM_MODULE_HANDLED=>   3;#  /* the module handled the request, so stop. */
	use constant    RLM_MODULE_INVALID=>   4;#  /* the module considers the request invalid. */
	use constant    RLM_MODULE_USERLOCK=>  5;#  /* reject the request (user is locked out) */
	use constant    RLM_MODULE_NOTFOUND=>  6;#  /* user not found */
	use constant    RLM_MODULE_NOOP=>      7;#  /* module succeeded without doing anything */
	use constant    RLM_MODULE_UPDATED=>   8;#  /* OK (pairs modified) */
	use constant    RLM_MODULE_NUMCODES=>  9;#  /* How many return codes there are */

	# Function to handle authorize
	sub authenticate {
		return RLM_MODULE_OK;

	}
	&authorize;
	# Function to handle authenticate
	sub authorize {
		# Check if the username is a MAC-Address
		if ($RAD_REQUEST{'User-Name'} =~ /\b(?:(?:[0-9a-fA-F]{1,2}):(?:[0-9a-fA-F]{1,2}):(?:[0-9a-fA-F]{1,2}):(?:[0-9a-fA-F]{1,2}):(?:[0-9a-fA-F]{1,2}):(?:[0-9a-fA-F]{1,2}))\b/) {
			#print "Login con MAC-Address\n";
			&autentica_wireless;
		} else {
			&autentica_ppp;
		}
	}

	sub autentica_wireless {
	open (LOG, ">>/var/log/radius_wireless.log");

		my $dbh= DBI->connect('DBI:Pg:dbname=neo', 'odoo', '');
		my $dbh1= DBI->connect('DBI:Pg:dbname=neo', 'odoo', '');

		my $sth = $dbh->prepare("SELECT username, password, is_locked, client_device_mac, net_id_name FROM WHERE client_device_mac = '$RAD_REQUEST{'User-Name'}'");
		$sth->execute();
		if ($sth->rows == 0) {
			print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Mac '$RAD_REQUEST{'User-Name'}' no cadastrado ou tiene datos de red incorectos!\r\n";
			return RLM_MODULE_REJECT;
		}

		if ($sth->rows > 1) {
			print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Mac $RAD_REQUEST{'User-Name'} com cadastro duplicado \r\n";
			return RLM_MODULE_REJECT;
		}

		while ((my $username,my $password,my $is_locked,my $client_device_mac,my $nome, my $ssid) = $sth->fetchrow_array()) {
		    if ($is_locked ne '0') {
		    return RLM_MODULE_REJECT;
		    }
			my $existessid = $dbh1->prepare("SELECT count(*) FROM isp_net WHERE name = '$RAD_REQUEST{'NAS-Port-Id'}'");
			$existessid->execute;
			if ($existessid->rows == 0) {
				print LOG "**********************************************\r\n";
				print LOG "O SSID nãpossui cadastro ou nãestár\n";
				print LOG "configurado corretamente, informe o adminitrador\r\n";
				print LOG "da rede\r\n";
				print LOG "SSID com erro: $RAD_REQUEST{'NAS-Port-Id'} \r\n";
				print LOG "IP: $RAD_REQUEST{'Framed-IP-Address'} \r\n";
				print LOG "**********************************************\r\n";
				return RLM_MODULE_REJECT;
			}

			if ($RAD_REQUEST{'NAS-Port-Id'} ne $ssid) {
				print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Mac $RAD_REQUEST{'User-Name'} nao liberado para autenticar nesta rede banco: $ssid solicitante: $RAD_REQUEST{'NAS-Port-Id'}\r\n";
				return RLM_MODULE_REJECT;
				exit(0);
			} else {
				print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: MAC $RAD_REQUEST{'User-Name'} autenticou no SSID:$RAD_REQUEST{'NAS-Port-Id'}!\r\n";
				return RLM_MODULE_OK;
			}
	    }
		close (LOG);
		$sth->finish;
		$dbh->disconnect();
		$dbh1->disconnect();
	}

	sub autentica_ppp {
	open (LOG, ">>/var/log/radius_ppp.log");
		my $dbh= DBI->connect('DBI:Pg:dbname=neo', 'odoo', '');
	#	my $sth = $dbh->prepare("SELECT username, password, is_locked, net_id_name, client_device_mac, upload, download, state, ip_address from account_analytic_account where username = '$RAD_REQUEST{'User-Name'}'");
		#my $sth = $dbh->prepare("SELECT aa.id,aa.username,aa.password,aa.is_locked,aa.net_id_name, aa.client_device_mac,pt.upload,pt.download,aa.state from account_analytic_account aa inner join account_analytic_invoice_line ail on aa.id = ail.analytic_account_id inner join product_template pt on ail.product_id = pt.id and pt.is_internet = 't' and aa.username='$RAD_REQUEST{'User-Name'}'");
#		my $sth = $dbh->prepare("SELECT aa.id,aa.username,aa.password,aa.is_locked,aa.is_fiber,aa.net_id_name,ig.name as PON,aa.client_device_mac,pt.upload,pt.download,aa.state from account_analytic_account aa
#inner join account_analytic_invoice_line ail on aa.id = ail.analytic_account_id 
#inner join product_template pt on ail.product_id = pt.id
#inner join isp_box ib on aa.box_id = ib.id 
#inner join isp_gpon ig on ib.gpon_id = ig.id  
#and pt.is_internet = 't'
#and aa.username='$RAD_REQUEST{'User-Name'}'");
		 my $sth = $dbh->prepare("SELECT aa.id,aa.username,aa.password,aa.is_locked,aa.is_fiber,aa.net_id_name,aa.box_id,aa.client_device_mac,pt.upload,pt.download,aa.state from account_analytic_account aa
inner join account_analytic_invoice_line ail on aa.id = ail.analytic_account_id
inner join product_template pt on ail.product_id = pt.id
and pt.is_internet = 't'
and aa.username='$RAD_REQUEST{'User-Name'}'");
		$sth->execute();

		my $ssid_id = $dbh->prepare("SELECT id FROM isp_net where name='$RAD_REQUEST{'NAS-Port-Id'}'");
		$ssid_id->execute;
		my @ssid_id = $ssid_id->fetchrow_array;

		my $ssid_allow = $dbh->prepare("SELECT id FROM isp_net where name='$RAD_REQUEST{'NAS-Port-Id'}' and allow_unknown='1'");
		$ssid_allow->execute;

	    if ($sth->rows == 0) {
		print LOG "**********************************************\r\n";
		print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $RAD_REQUEST{'User-Name'} nao esta cadastrado!\r\n";
		print LOG "**********************************************\r\n";
		return RLM_MODULE_REJECT;
			exit(0);
	    }

		while ((my $id, my $username,my $password,my $is_locked,my $fibra, my $net_id_name, my $box_id, my $client_device_mac,my $upload,my $download,my $state,) = $sth->fetchrow_array()) {
		$upload = $upload*1024;
		$download = $download*1024;
	   # if the state is not open or pending quick off
	      if ($state eq 'cancelled') {
                print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $username esta desabilitado! \r\n";
                return RLM_MODULE_REJECT;
                        exit(0);
                }
	   # check the plain is assigned
		if (!$download) {
			 print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $RAD_REQUEST{'User-Name'} nao teve o plano identificado!\r\n";
		 return RLM_MODULE_REJECT;
		 exit(0);
		}
	   #get PON for fiber users
		if ($fibra == '1'){
			$sth = $dbh->prepare("SELECT ig.name from isp_box ib inner join isp_gpon ig on ib.gpon_id = ig.id and ib.id = '$box_id'");
                        $sth->execute();
                        $net_id_name = $sth->fetchrow_array;
		}
	   # assign a dinamic ip address	
			my $verificaip = $dbh->prepare("select name from isp_ip where contract_id = '$id'");	
			$verificaip->execute;
  				     my	$ip_address = $verificaip->fetchrow_array;
						if (!is_ipv4($ip_address)) {			
							my $asignaipdinamico = $dbh->prepare("select name from isp_ip where contract_id is null and name between '143.202.209.1' and '143.202.211.255' order by name asc limit 1");	
						$asignaipdinamico->execute;
        			$ip_address = $asignaipdinamico->fetchrow_array;
		my $gravaip = $dbh->prepare("update isp_ip set contract_id = '$id' where name = '$ip_address'");
			   $gravaip->execute;
			} 
				
	   #check password
		if ($password ne $RAD_REQUEST{'User-Password'}) {
	        	print LOG "**********************************************\r\n";
	        	print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $RAD_REQUEST{'User-Name'} esta com a senha incorreta! Senha banco: $password - Senha Recebida: $RAD_REQUEST{'User-Password'} ";
        		print LOG "**********************************************\r\n";
        	#	my $sthcorrigepassword = $dbh->prepare("update account_analytic_account set password='$RAD_REQUEST{'User-Password'}' where username = '$username'");
            	#$sthcorrigepassword->execute;
		        return RLM_MODULE_REJECT;
                	exit(0);
    		}

		#Check the ssid
		if ($net_id_name ne $RAD_REQUEST{'NAS-Port-Id'}){
       			my $existessid = $dbh->prepare("SELECT count(*) FROM isp_net WHERE name = '$RAD_REQUEST{'NAS-Port-Id'}'");
            		$existessid->execute;
            			if ($existessid->rows == 0) {
				print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: SSID Inexistente $RAD_REQUEST{'NAS-Port-Id'}\r\n";
				return RLM_MODULE_REJECT;
				exit(0);
}
		if ($fibra ne '1'){
			print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $username esta com SSID incorreto -- banco:$net_id_name atual:$RAD_REQUEST{'NAS-Port-Id'}\r\n";
		} else {
			print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $username esta com CAIXA incorreta -- banco:$net_id_name atual:$RAD_REQUEST{'NAS-Port-Id'}\r\n";
}
		if ($ssid_allow->rows == 1) {
            		my $sthcorrigessid = $dbh->prepare("update account_analytic_account set net_id=@ssid_id, net_id_name='$RAD_REQUEST{'NAS-Port-Id'}' where username = '$username'");
            		$sthcorrigessid->execute;
		}
			return RLM_MODULE_REJECT;
			exit(0);
		} else {
			if ($RAD_REQUEST{'Calling-Station-Id'} ne $client_device_mac) {
				# Case the client MAC-Address is differente, update the register with his new MAC-Address
				print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $username com mac incorreto! Mac atual: $RAD_REQUEST{'Calling-Station-Id'} $client_device_mac\r\n";
		#		my $sthcorrigemac = $dbh->prepare("update account_analytic_account set client_device_mac='$RAD_REQUEST{'Calling-Station-Id'}' where username = '$username'");
		#		$sthcorrigemac->execute;
		#		print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $username corrigiu mac\r\n";
		#		return RLM_MODULE_REJECT;
		#		exit(0);
			}
		}
		if ($is_locked eq '100') {
			#print "Is Blocked\n";
			# Redirect the client to an warning page
			my ($ip1,$ip2,$ip3,$ip4) = split(/\./, $ip_address);
			$RAD_REPLY{'Framed-IP-Address'} = "10.20.$ip3.$ip4";
			$RAD_REPLY{'Mikrotik-Rate-Limit'} = "$upload\K/$download\K";
			print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $username encaminhado a pagina de aviso \r\n";
			return RLM_MODULE_OK;
			exit(0);
		} else {
			# Here finally the user connect correctly
			print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $username conectou, ip: $ip_address PLANO DOWNLOAD: $download UPLOAD: $upload\r\n";
		 	$RAD_REPLY{'Framed-IP-Address'} = "$ip_address";
			$RAD_REPLY{'Mikrotik-Rate-Limit'} = "$upload\K/$download\K";
			return RLM_MODULE_OK;
			exit(0);
		}
	}
	close (LOG);
	$sth->finish;
	$dbh->disconnect();
	exit(0);
}

# Function to handle accounting

sub accounting_start {
	my $DATA = POSIX::strftime("%Y/%m/%d",localtime);
	my $HORARIO = POSIX::strftime("%k:%M:%S",localtime);

	my $dbh= DBI->connect('DBI:Pg:dbname=neo_banco;host=177.39.215.13', 'postgres', 's1@ck');
	my $dbh1= DBI->connect('DBI:Pg:dbname=neo', 'odoo', '');

        my $sth = $dbh1->prepare("SELECT pt.name,aa.state from account_analytic_account aa
inner join account_analytic_invoice_line ail on aa.id = ail.analytic_account_id
inner join product_template pt on ail.product_id = pt.id
and pt.is_internet = 't'
and aa.username='$RAD_REQUEST{'User-Name'}'");
		$sth->execute();
			my ($planoname,$state) = $sth->fetchrow_array();	

        my $sth = $dbh->prepare("SELECT sess_id from ISP_CONNECTION where sess_id = '$RAD_REQUEST{'Acct-Session-Id'}' and usuario = '$RAD_REQUEST{'User-Name'}'");
     $sth->execute();
       	       if ($sth->rows == 0){
		$sth = $dbh->prepare("INSERT INTO ISP_CONNECTION(usuario,router,rede,data,hora,ip_conexao,sess_id,plano,state) VALUES ('$RAD_REQUEST{'User-Name'}','$RAD_REQUEST{'NAS-Identifier'}','$RAD_REQUEST{'NAS-Port-Id'}','$DATA','$HORARIO','$RAD_REQUEST{'Framed-IP-Address'}','$RAD_REQUEST{'Acct-Session-Id'}','$planoname','$state')");
		          $sth->execute();
}
   $sth->finish;
   $dbh->disconnect();
   $dbh1->disconnect();
    return RLM_MODULE_OK;
}

sub accounting_stop {
	my $dbh= DBI->connect('DBI:Pg:dbname=neo_banco;host=177.39.215.13', 'postgres', 's1@ck');
		my $sth = $dbh->prepare("update ISP_CONNECTION set tempo='$RAD_REQUEST{'Acct-Session-Time'}', closed = 't', terminate_cause = '$RAD_REQUEST{'Acct-Terminate-Cause'}' where sess_id = '$RAD_REQUEST{'Acct-Session-Id'}'");
	         $sth->execute();
  	 $sth->finish;
   $dbh->disconnect();
	 my $dbh1= DBI->connect('DBI:Pg:dbname=neo', 'odoo', '');
                  my $ipfixo = $dbh1->prepare("select * from isp_ip where name = '$RAD_REQUEST{'Framed-IP-Address'}' and in_use = 't'");
                        $ipfixo->execute;
       	       		 if ($ipfixo->rows == 0){
	   		my $zeraip = $dbh1->prepare("update isp_ip set contract_id = NULL where name = '$RAD_REQUEST{'Framed-IP-Address'}'");
				$zeraip->execute;
  	 		$zeraip->finish;
		   $dbh1->disconnect();
	}
   return RLM_MODULE_OK;

}

# Function to handle checksimul
sub checksimul {
    return RLM_MODULE_OK;

}

# Function to handle post_auth
sub post_auth {
    return RLM_MODULE_OK;

}

sub log_request_attributes {
    for (keys %RAD_REQUEST) {
            &radiusd::radlog(1, "RAD_REQUEST: $_ = $RAD_REQUEST{$_}");
    }
}
