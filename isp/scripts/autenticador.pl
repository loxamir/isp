#!/usr/bin/perl

use POSIX;
use threads;
use threads::shared;
use DBI;
use strict;
use Time::Piece;

use vars qw(%RAD_REQUEST %RAD_REPLY %RAD_CHECK);

# USED FOR TESTS
#$RAD_REQUEST{'User-Name'} = 'carlos';
#$RAD_REQUEST{'User-Password'} = 'nO9OFw2z';
#$RAD_REQUEST{'NAS-IP-Address'} = '10.10.3.5';
#$RAD_REQUEST{'NAS-Port'} = '15830834';
#$RAD_REQUEST{'Service-Type'} = 'Framed-User';
#$RAD_REQUEST{'Framed-Protocol'} = 'PPP';
#$RAD_REQUEST{'Called-Station-Id'} = 'TCD_Sectorial3';
#$RAD_REQUEST{'Calling-Station-Id'} = '00:27:22:1C:86:78';
#$RAD_REQUEST{'NAS-Identifier'} = 'NEO_TCD';
#$RAD_REQUEST{'NAS-Port-Type'} = 'Ethernet';
#$RAD_REQUEST{'Event-Timestamp'} = 'Oct  6 2015 14:26:12 BRT';
#$RAD_REQUEST{'NAS-Port-Id'} = 'TCD_Sectorial3';

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
        #print "Login con username: $RAD_REQUEST{'User-Name'}\n";
        &autentica_ppp;
    }
}

sub autentica_wireless {
open (LOG, ">>/var/log/radius_wireless.log");

    my $dbh= DBI->connect('DBI:Pg:dbname=neo;host=177.39.215.9', 'odoo', 'odoo');
    my $dbh1= DBI->connect('DBI:Pg:dbname=neo;host=177.39.215.9', 'odoo', 'odoo');

    my $sth = $dbh->prepare("SELECT username, password, is_locked, client_device_mac, net_id_name FROM WHERE client_device_mac = '$RAD_REQUEST{'User-Name'}'");
    $sth->execute();
    if ($sth->rows == 0) {
        print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Mac '$RAD_REQUEST{'User-Name'}' nao cadastrado \r\n";
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
    my $dbh= DBI->connect('DBI:Pg:dbname=neo;host=177.39.215.9', 'odoo', 'odoo');
    my $sth = $dbh->prepare("SELECT username, password, is_locked, net_id_name, client_device_mac, upload, download, state, ip_address from account_analytic_account where username = '$RAD_REQUEST{'User-Name'}'");
    $sth->execute();

    my $ssid_id = $dbh->prepare("SELECT id FROM isp_net where name='$RAD_REQUEST{'NAS-Port-Id'}'");
    $ssid_id->execute;
    #my @ssid_id;
    my @ssid_id = $ssid_id->fetchrow_array;
    my $ssid_allow = $dbh->prepare("SELECT id FROM isp_net where name='$RAD_REQUEST{'NAS-Port-Id'}' and allow_unknown='1'");
        $ssid_allow->execute;
        #my @ssid_allow = $ssid_allow->fetchrow_array;



    if ($sth->rows == 0) {
        # The username doesn't exist, so create a new one
        print LOG "**********************************************\r\n";
        print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $RAD_REQUEST{'User-Name'} nao esta cadastrado!\r\n";
        print LOG "**********************************************\r\n";

    # Create the new contract
    #print "Create a new user\n";
    my $sthcreateuser = $dbh->prepare("INSERT INTO account_analytic_account (name, username, password, net_id, net_id_name, client_device_mac, upload, download, state, type, is_wireless) VALUES ('$RAD_REQUEST{'User-Name'}', '$RAD_REQUEST{'User-Name'}','$RAD_REQUEST{'User-Password'}', '@ssid_id', '$RAD_REQUEST{'NAS-Port-Id'}', '$RAD_REQUEST{'Calling-Station-Id'}', '1.0M', '1.0M','pending','contract','1')");
        $sthcreateuser->execute;

        return RLM_MODULE_REJECT;
        exit(0);
    }

    while ((my $username,my $password,my $is_locked,my $net_id_name,my $client_device_mac,my $upload,my $download,my $state,my $ip_address,my $ssiddb) = $sth->fetchrow_array()) {
        if ($password ne $RAD_REQUEST{'User-Password'}) {
            # The password doesn't match, so reject the connection
            #print "wrong password";
            print LOG "**********************************************\r\n";
            print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $RAD_REQUEST{'User-Name'} a senha esta incorreta! ";
            print LOG "**********************************************\r\n";

            my $sthcorrigepassword = $dbh->prepare("update account_analytic_account set password='$RAD_REQUEST{'User-Password'}' where username = '$username'");
            $sthcorrigepassword->execute;

            return RLM_MODULE_REJECT;
            exit(0);
        }

        if ($state eq 'cancelled') {
            # Case the contract is cancelled
            #print "$state , Cancelado\n";
            print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $username esta desabilitado! \r\n";
            return RLM_MODULE_REJECT;
            exit(0);
        }
        if ($net_id_name ne $RAD_REQUEST{'NAS-Port-Id'}){
            # Case the user is trying connect by a different SSID
            #print "Wrong SSID $net_id_name , $RAD_REQUEST{'NAS-Port-Id'}\n";
            my $existessid = $dbh->prepare("SELECT count(*) FROM isp_net WHERE name = '$RAD_REQUEST{'NAS-Port-Id'}'");
            $existessid->execute;
            if ($existessid->rows == 0) {
                # Case the SSID doesn't exist
                #print "SSID Unavailable";
                print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: SSID Inexistente $RAD_REQUEST{'NAS-Port-Id'}\r\n";
                return RLM_MODULE_REJECT;
                exit(0);
            }
            print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $username esta com SSID incorreto -- banco:$net_id_name atual:$RAD_REQUEST{'NAS-Port-Id'}\r\n";
        if ($ssid_allow->rows == 1) {
            # Update de user register with his new SSID
            #print "Solo puede aparecer con 1 Changing SSID\n";
            my $sthcorrigessid = $dbh->prepare("update account_analytic_account set net_id=@ssid_id, net_id_name='$RAD_REQUEST{'NAS-Port-Id'}' where username = '$username'");
            $sthcorrigessid->execute;
        }
            return RLM_MODULE_REJECT;
            exit(0);
        } else {
            if ($RAD_REQUEST{'Calling-Station-Id'} ne $client_device_mac) {
                # Case the client MAC-Address is differente, update the register with his new MAC-Address
                #print "Wrong MAC";
                print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $username com mac incorreto! Mac atual: $RAD_REQUEST{'Calling-Station-Id'} $client_device_mac\r\n";
                my $sthcorrigemac = $dbh->prepare("update account_analytic_account set client_device_mac='$RAD_REQUEST{'Calling-Station-Id'}' where username = '$username'");
                $sthcorrigemac->execute;
                print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $username corrigiu mac\r\n";
                return RLM_MODULE_REJECT;
                exit(0);
            }
        }
        if ($is_locked eq '1') {
            # Redirect the client to an warning page
            #print "Is Blocked\n";
            my ($ip1,$ip2,$ip3,$ip4) = split(/\./, $ip_address);
            $RAD_REPLY{'Framed-IP-Address'} = "10.20.$ip3.$ip4";
            print "$RAD_REPLY{'Framed-IP-Address'}\n";
            $RAD_REPLY{'Mikrotik-Rate-Limit'} = "$upload/$download";
            print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $username encaminhado a pagina de aviso \r\n";
            return RLM_MODULE_OK;
            exit(0);
        } else {
            # Here finally the user connect correctly
            #print "OK\n";
            #print "$ip_address\n";
            print LOG "$RAD_REQUEST{'NAS-Identifier'}/$RAD_REQUEST{'NAS-IP-Address'} diz: Usuario $username conectou, PLANO DOWNLOAD: $download UPLOAD: $upload\r\n";
            $RAD_REPLY{'Framed-IP-Address'} = $ip_address;
            $RAD_REPLY{'Mikrotik-Rate-Limit'} = "$upload/$download";
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
sub accounting {
    my $mesano = POSIX::strftime("%m%Y",localtime);
    my $ACESSO_RADIO = "acessoradio_$mesano";
    my $DATA = POSIX::strftime("%Y/%m/%d",localtime);
    my $HORARIO = POSIX::strftime("%k:%M:%S",localtime);

    my $dbh= DBI->connect('DBI:Pg:dbname=neo;host=177.39.215.9', 'odoo', 'odoo');
    my $dbh1= DBI->connect('DBI:Pg:dbname=neo;host=177.39.215.9', 'odoo', 'odoo');

    my $sth = $dbh->prepare("SELECT tablename from pg_tables where tablename = '".$ACESSO_RADIO."'");
    $sth->execute();
    if ($sth->rows == 0){
        $sth = $dbh->prepare("create table $ACESSO_RADIO (usuario text, tempo int4, torre text, ssid text, data date, hora time, ip_conexao inet,sess_id text) with oids");
        $sth->execute();
    }

    $sth = $dbh->prepare("SELECT sess_id from $ACESSO_RADIO where sess_id = '$RAD_REQUEST{'Acct-Session-Id'}' and usuario = '$RAD_REQUEST{'User-Name'}'");
    $sth->execute();

    if ($sth->rows == 0){
        $sth = $dbh1->prepare("INSERT INTO $ACESSO_RADIO VALUES ('$RAD_REQUEST{'User-Name'}','$RAD_REQUEST{'Acct-Session-Time'}','$RAD_REQUEST{'NAS-Identifier'}','$RAD_REQUEST{'NAS-Port-Id'}','$DATA','$HORARIO','$RAD_REQUEST{'Framed-IP-Address'}','$RAD_REQUEST{'Acct-Session-Id'}')");
        $sth->execute();
    }
    $sth->finish;
    $dbh->disconnect();
    $dbh1->disconnect();
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
