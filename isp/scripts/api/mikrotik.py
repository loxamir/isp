#!/usr/bin/env python
# Project: Neo Telecom
# Author: Rossa S.A.
# Programmer: Marcelo Pickler
# Date: 14/09/2015

import paramiko
import logging

_logger = logging.getLogger(__name__)

class Mikrotik:
    """Read the parameters from an Ubiquiti access point."""

    def __init__(self, host, username, password, port=22):
        self.ssh = paramiko.SSHClient()
        self.ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.ssh.connect(
            host, username=username, password=password, port=port, timeout=2)

    def get_user_data(self, username):
        command = "/ppp active print where name=%s" % username
        stdin, stdout, stderr = self.ssh.exec_command(command)
        type(stdin)
        answer = stdout.readlines()
        list = ' '.join(answer[2].split())
        list = list.split(' ')
        if list[0] is not "":
            mac_address = list[4]
            ip_address = list[5]
            command = "/queue simple print stats where name=<pppoe-%s>" % username
            stdin, stdout, stderr = self.ssh.exec_command(command)
            type(stdin)
            answer = stdout.readlines()
            data = answer[4].split("bytes=")[1].split(" ")[0]
            upload = int(data.split("/")[0])*8
            download = int(data.split("/")[1])*8
            print "UPLOAD: %s" % upload
            print "DOWNLOAD: %s" % download

            return {
                    'mac': mac_address,
                    'ip': ip_address,
                    'upload': upload,
                    'download': download,
            }
        else:
            return False

    def disconnect_user(self, username):
        command = "/ppp active remove [find name=%s]" % username
        stdin, stdout, stderr = self.ssh.exec_command(command)
        type(stdin)

    def get_user_uptime(self, username):
        command = "/ppp active print detail where name=%s" % username
        stdin, stdout, stderr = self.ssh.exec_command(command)
        type(stdin)
        answer = stdout.readlines()
        if len(answer) >= 3:
            uptime = answer[2].split("uptime=")
            uptime = uptime[1].split(" ")[0]
        else:
            uptime = "No Conectado"
        return uptime

    def get_user_ip(self, username):
        command = "/ppp active print detail where name=%s" % username
        stdin, stdout, stderr = self.ssh.exec_command(command)
        type(stdin)
        answer = stdout.readlines()
        if len(answer) >= 3:
            uptime = answer[2].split("address=")
            uptime = uptime[1].split(" ")[0]
        else:
            uptime = "No Conectado"
        return uptime

    def get_user_mac(self, username):
        command = "/ppp active print detail where name=%s" % username
        stdin, stdout, stderr = self.ssh.exec_command(command)
        type(stdin)
        answer = stdout.readlines()
        if len(answer) >= 3:
            uptime = answer[1].split('caller-id="')
            uptime = uptime[1].split('"')[0]
        else:
            uptime = "No Conectado"
        return uptime

    def get_user_band_limit(self, username):
        command = "/queue simple print where name=<pppoe-%s>" % username
        stdin, stdout, stderr = self.ssh.exec_command(command)
        type(stdin)
        answer = stdout.readlines()
#        return answer
        for string in answer:
            _logger.warning("string %s result: %s" % (string, string.find("limit-at")))
            
            if string.find("limit-at=") != -1:
                _logger.warning("band_limit: %s" % string)
                band_limit = string.split("limit-at=")[1].split(" ")[0].split("/")
                return {'upload': band_limit[0], 'download': band_limit[1]}
            
