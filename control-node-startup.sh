#!/bin/bash

# Update the system
sudo apt-get update

# Install etcd server
sudo apt-get install -y etcd

# Set up etcd to run at startup
sudo systemctl enable etcd
sudo systemctl start etcd

# Install Go
sudo apt-get install -y software-properties-common
sudo add-apt-repository ppa:longsleep/golang-backports
sudo apt-get update
sudo apt-get install -y golang-go

echo "export GOPATH=$HOME/go" >> $HOME/.profile
echo "export PATH=$PATH:/usr/lib/go/bin:$GOPATH/bin" >> $HOME/.profile
source $HOME/.profile

# Basic etcd configuration
INTERNAL_IP=$(curl http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip -H "Metadata-Flavor: Google")

cat <<EOF | sudo tee /etc/default/etcd
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="http://$INTERNAL_IP:2380"
ETCD_LISTEN_CLIENT_URLS="http://$INTERNAL_IP:2379,http://127.0.0.1:2379"
ETCD_NAME="$(hostname)"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://$INTERNAL_IP:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://$INTERNAL_IP:2379"
ETCD_INITIAL_CLUSTER="$(hostname)=http://$INTERNAL_IP:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF

# Restart etcd with new settings
sudo systemctl restart etcd

# Install containerd
sudo apt-get install -y containerd

# Configure containerd to use CNI
sudo mkdir -p /etc/containerd
cat <<EOF | sudo tee /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true

[plugins."io.containerd.grpc.v1.cri".cni]
  bin_dir = "/opt/cni/bin"
  conf_dir = "/etc/cni/net.d"
EOF

# Install CNI plugins
wget https://github.com/containernetworking/plugins/releases/download/v1.0.1/cni-plugins-linux-amd64-v1.0.1.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -xzvf cni-plugins-linux-amd64-v1.0.1.tgz -C /opt/cni/bin

# Configure CNI networking
sudo mkdir -p /etc/cni/net.d
cat <<EOF | sudo tee /etc/cni/net.d/10-mynet.conflist
{
  "cniVersion": "1.0.0",
  "name": "mynet",
  "plugins": [
    {
      "type": "bridge",
      "bridge": "cni0",
      "isGateway": true,
      "ipMasq": true,
      "ipam": {
        "type": "host-local",
        "subnet": "10.22.0.0/16",
        "routes": [
          { "dst": "0.0.0.0/0" }
        ]
      }
    },
    {
      "type": "portmap",
      "capabilities": {
        "portMappings": true
      },
      "snat": true
    }
  ]
}
EOF

# Ensure containerd and CNI are set up properly
sudo systemctl restart containerd

# Install Docker
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker

# Deploy a Docker registry on port 5000
sudo docker run -d -p 5000:5000 --restart=always --name registry registry:2

# Get container orchestrator
cd /home/ubuntu/
git clone https://github.com/0xKowalski1/container-orchestrator.git

# Push minecraft to registry
cd /home/ubuntu/container-orchestrator/container-examples/minecraft
sh pushToRegistry.sh

cd /home/ubuntu/container-orchestrator
# Change config & create mounts/logs dirs
mkdir -p mounts logs
sudo apt-get update && sudo apt-get install -y jq

# Update the config.json with correct paths using jq
jq '.storagePath = "/home/ubuntu/container-orchestrator/mounts/" |
    .logPath = "/home/ubuntu/container-orchestrator/logs/" |
    .cniPath = "/opt/cni/bin"' config.json > temp.json && mv temp.json config.json

# Reset network, should not have to do this
sh fullReset.sh
