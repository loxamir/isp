#!/usr/bin/env python
# Project: Neo Telecom
# Author: Rossa S.A.
# Programmer: Marcelo Pickler
# Date: 14/09/2015

import subprocess
import StringIO

# Read the parameters from an Ubiquiti access point


class Ping:
    def __init__(self, host):
        ping = subprocess.Popen(
            ["oping", "-c", "10", "-i", "0.1", host],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        out, error = ping.communicate()
        self.out = out

    def get_mean_and_loss(self):
        answer = StringIO.StringIO(self.out)
        answer = answer.readlines()
        lista = answer[13]
        datos = lista.split(' ')
        loss = datos[5].split('.')
        loss = loss[0]
        mean = datos[9].split('.')
        mean = float(mean[0])
        mean = mean/10

        return {
            'mean': mean,
            'loss': loss,
        }
