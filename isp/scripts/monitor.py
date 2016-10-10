#!/usr/bin/env python
# Project: Neo Telecom
# Author: Rossa S.A.
# Programmer: Marcelo Pickler
# Date: 14/09/2015

from api.ubiquiti import Ubiquiti
from api.mikrotik import Mikrotik
from api.ping import Ping
import xmlrpclib
# import paramiko
import subprocess
from datetime import datetime as time

url = 'http://143.202.208.9:8069'
db = 'neo'
username = 'monitor'
password = '123'

common = xmlrpclib.ServerProxy('{}/xmlrpc/2/common'.format(url))
common.version()
uid = common.authenticate(db, username, password, {})

# Check if the Access points are online
models = xmlrpclib.ServerProxy('{}/xmlrpc/2/object'.format(url))
users = models.execute_kw(
    db, uid, password, 'account.analytic.account', 'search_read',
    [[['net_id', 'in', [9]]]],
    {
        'fields': [
            'code',
            'username',
            'wireless_router_ip',
            'is_wireless',
            'wireless_router_login',
            'wireless_router_password',
            'wireless_router_port',
            'wireless_ap_ip',
            'wireless_ap_login',
            'wireless_ap_password',
            'wireless_ap_port',
            'id'
        ],
    })

# Make some network measures in for monitor the clients connection
for values in users:
    if values['is_wireless'] is True:
        try:
            self = Mikrotik(
                host=values['wireless_router_ip'],
                username=values['wireless_router_login'],
                password=values['wireless_router_password'],
                port=values['wireless_router_port'])
            user_data = Mikrotik.get_user_data(self, values['username'])
            self = Ubiquiti(
                host=values['wireless_ap_ip'],
                username=values['wireless_ap_login'],
                password=values['wireless_ap_password'],
                port=values['wireless_ap_port'])
            radio = Ubiquiti.get_signal(self, user_data['mac'])
            user_data['signal'] = radio['signal'] or 0
            user_data['noise'] = radio['noise'] or 0
            ping = Ping(host=user_data['ip'])
            datos = ping.get_mean_and_loss()
            user_data['mean'] = datos['mean']
            user_data['loss'] = datos['loss']
            print "Estado: Online, Usuario: "+str(values['username']) + \
                ", Contrato: "+str(values['code'])
            command = 'sh /opt/odoo/sistema-social/rossa/isp/isp/scripts/' + \
                'rrd/sinalping.sh %s %s %s %s %s %s %s' \
                % (
                    user_data['signal'], 
                    user_data['noise'], 
                    user_data['mean'],
                    user_data['loss'],  
                    user_data['download'],
                    user_data['upload'], 
                    values['code']
                  )
        except:
            print "Estado: Offline, Usuario: "+str(values['username']) + \
                ", Contrato: "+str(values['code'])
            command = 'sh /opt/odoo/sistema-social/rossa/isp/isp/scripts/' + \
                'rrd/sinalping.sh %s %s %s %s %s %s %s' \
                % (0, 0, 0, 0, 0, 0, values['code'])
        print time.now()
        print command
        subprocess.Popen([command], shell=True)
        #subprocess.call([command])
