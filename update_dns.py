#!/usr/bin/env python3
from kubernetes import client, config
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--ip', required=True)
parser.add_argument('--name', required=True)
parser.add_argument('--configmap', default='coredns')
parser.add_argument('--namespace', default='kube-system')
args = parser.parse_args()

config.load_kube_config()

v1 = client.CoreV1Api()

entry = args.ip + ' ' + args.name + '\n'

configmap = v1.read_namespaced_config_map(args.configmap,args.namespace)
configmap.data['NodeHosts'] += entry
resp = v1.replace_namespaced_config_map(args.configmap, args.namespace, configmap)

if not resp:
    print('Error updating configMap')
else:
    print('OK')
