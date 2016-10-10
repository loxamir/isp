#!/usr/bin/env python
# Project: Neo Telecom
# Author: Rossa S.A.
# Programmer: Marcelo Pickler
# Date: 14/09/2015

import paramiko
import ast


class Ubiquiti:
    """Read the parameters from an Ubiquiti access point."""

    def __init__(self, host, username, password, port=22):
        self.ssh = paramiko.SSHClient()
        self.ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.ssh.connect(
            host, username=username, password=password, port=port, timeout=2)

    def get_signal(self, mac_address):
        command = "wstalist -a %s" % mac_address
        stdin, stdout, stderr = self.ssh.exec_command(command)
        type(stdin)
        answer = stdout.readlines()
        retorno = ""
        for line in answer:
            retorno = "%s%s" % (retorno, line)
        list = ast.literal_eval(retorno)
        line = 0
        signal = ""
        noise = ""
        while line < len(list):
            signal = list[line]['signal']
            noise = list[line]['noisefloor']
            line += 1
        return {'signal': signal, 'noise': noise}
