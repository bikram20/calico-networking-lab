#!/usr/bin/env bash

echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections

# Latest updates
apt-get update 
apt-get upgrade -y
apt-get install jq wget curl ipset ipvsadm  -y
apt-get install dialog apt-utils -y

# Docker
apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common -y

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

apt-get update 
sudo apt-get install docker-ce docker-ce-cli containerd.io -y
apt-mark hold docker-ce docker-ce-cli containerd.io

cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Restart docker.
systemctl daemon-reload
systemctl restart docker


# Kubeadm
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo apt-get update && sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Pull kubeadm images
docker pull k8s.gcr.io/kube-apiserver:v1.18.1
docker pull k8s.gcr.io/kube-controller-manager:v1.18.1
docker pull k8s.gcr.io/kube-scheduler:v1.18.1
docker pull k8s.gcr.io/kube-proxy:v1.18.1
docker pull k8s.gcr.io/pause:3.2
docker pull k8s.gcr.io/etcd:3.4.3-0
docker pull k8s.gcr.io/coredns:1.6.7


# Pull Calico images and yaml's
curl https://docs.projectcalico.org/manifests/calico.yaml -O

docker pull calico/cni:v3.13.2
docker pull calico/pod2daemon-flexvol:v3.13.2
docker pull calico/node:v3.13.2
docker pull calico/kube-controllers:v3.13.2

# Download calicoctl and keep under /usr/local/bin
wget  https://github.com/projectcalico/calicoctl/releases/download/v3.13.2/calicoctl
chmod +x calicoctl
mv calicoctl /usr/local/bin

cat << EOF >> calicoctl.cfg
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  datastoreType: "kubernetes"
  kubeconfig: "/home/vagrant/.kube/config"
EOF

sudo mkdir -p /etc/calico
mv calicoctl.cfg /etc/calico

# Clean up
sudo apt-get clean -y
sudo apt-get autoremove --purge -y

