#!/usr/bin/python

import os
import sys

CFG = {'windows': {'hosts': ['ballantyne.home'],                                                                               'ports': [9182],           'path': '/metrics'},
       'jenkins': {'hosts': ['jenkins-exporter.jenkins-exporter.svc.cluster.local'],                                           'ports': [9182],           'path': '/metrics'},
       'kafka':   {'hosts': ['s3.ubuntu.home','s7.ubuntu.home','s8.ubuntu.home'],                                              'ports': [7202,7204,9999], 'path': '/metrics'},
       'unix':    {'hosts': ['s2.ubuntu.home','s3.ubuntu.home','s4.ubuntu.home','nas.home','wdmycloud.home','pi.ubuntu.home'], 'ports': [9100],           'path': '/metrics'},
       'minio':   {'hosts': ['s1.ubuntu.home'],                                                                                'ports': [9000],           'path': '/minio/v2/metrics/cluster'}}


def scanHosts(cfg):

    for name in cfg:
        for host in cfg[name]['hosts']:
            for port in cfg[name]['ports']:
                file = '{}.{}.{}'.format(host, port, name)
                cmd = 'curl -s http://{0}:{1}{2} > {3}'.format(host, port, cfg[name]['path'], file)
                print (cmd)
                os.system(cmd)
    return 0

if __name__ == "__main__":
    sys.exit(scanHosts(CFG))
