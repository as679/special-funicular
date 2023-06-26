#!/usr/bin/env bash

. /tmp/variables

domain=testing.local
keycloak_domain=keycloak.${domain}
nic=`ip r | grep default | cut -d' ' -f5`
ip=`ip addr show dev ${nic} | grep 'inet ' | awk '{print $2}' | cut -d/ -f1`

apt install -y python3-pip unzip jq
pip3 install kubernetes boto3

# Install K3S
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.24.13+k3s1 K3S_KUBECONFIG_MODE="644" sh -
sleep 60
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
crictl img | grep -v IMAGE | awk '{print $1":"$2}' > /tmp/k3s.lst
cat /tmp/k3s.lst > /tmp/total.lst

# Setup Helm and install operators
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

helm repo add strimzi https://strimzi.io/charts/
helm repo add elastic https://helm.elastic.co
helm repo add prometheus https://prometheus-community.github.io/helm-charts
helm repo add cequence https://cequence.gitlab.io/helm-charts
helm install strimzi strimzi/strimzi-kafka-operator -n kafka-system --create-namespace --set watchAnyNamespace=true --version $KAFKA
helm install eck elastic/eck-operator -n elastic-system --create-namespace --version $ECK
sleep 10
sudo crictl img | grep -v IMAGE | awk '{print $1":"$2}' | grep -vf /tmp/k3s.lst > /tmp/operators.lst
cat /tmp/operators.lst >> /tmp/total.lst

# Prometheus
helm install monitoring prometheus/kube-prometheus-stack -n monitoring --create-namespace --version $MONITORING
sleep 30
crictl img | grep -v IMAGE | awk '{print $1":"$2}' | grep -vf /tmp/total.lst > /tmp/prometheus.lst
cat /tmp/prometheus.lst >> /tmp/total.lst

# Namespace and keycloak
kubectl create ns cqai-system
kubectl create secret docker-registry regcred --docker-server=registry.gitlab.com --docker-username=$REGISTRY_USER --docker-password=$REGISTRY_PASS -n cqai-system
sed -i "s/KEYCLOAK_DOMAIN/$keycloak_domain/g" /tmp/repo/keycloak.yml
kubectl apply -f /tmp/repo/keycloak.yml
sleep 30
crictl img | grep -v IMAGE | awk '{print $1":"$2}' | grep -vf /tmp/total.lst > /tmp/keycloak.lst
cat /tmp/keycloak.lst >> /tmp/total.lst

# Cequence
python3 /tmp/repo/update_dns.py --ip $ip --name $keycloak_domain
sed -i "s/KEYCLOAK_DOMAIN/$keycloak_domain/g" /tmp/repo/cqai-values.yml
sed -i "s/DOMAIN/$domain/g" /tmp/repo/cqai-values.yml
helm upgrade --install cqai cequence/cequence-asp --namespace cqai-system --values /tmp/repo/cqai-values.yml --skip-crds --version $CQAI
bash /tmp/repo/wait_for_it.sh
crictl img | grep -v IMAGE | awk '{print $1":"$2}' | grep -vf /tmp/total.lst > /tmp/cequence.lst
cat /tmp/cequence.lst >> /tmp/total.lst

# Create tarfile and upload
filename=cequence-$CQAI-`date +%s`.tar.gz
tar -zcvf /tmp/$filename /tmp/*.lst /tmp/variables
aws s3 cp /tmp/$filename s3://image-dropbox/image_lst/$filename


touch /tmp/i-ran
sudo shutdown -h now
