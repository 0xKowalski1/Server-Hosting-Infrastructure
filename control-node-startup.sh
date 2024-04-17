#!/bin/bash

touch /home/ubuntu/startup-running

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

# Create config.json 
cat <<EOF >/home/ubuntu/config.json
{
  "namespace": "development",
  "nodeIp": "",
  "controlNodeIp": "",
  "containerdSocketPath": "",
  "storagePath": "",
  "cniPath": "",
  "networkConfigPath": "",
  "networkConfigFileName": "",
  "networkNamespacePath": "",
  "logPath": ""
}
EOF

# URL for the control-node binary from GitHub Releases
CONTROL_NODE_URL="https://github.com/0xKowalski1/container-orchestrator/releases/download/v0.0.1/control-node"

# Use wget to download the binary
wget $CONTROL_NODE_URL -O /home/ubuntu/control-node

# Make the downloaded binary executable
chmod +x /home/ubuntu/control-node

echo "control-node downloaded and set as executable."

rm /home/ubuntu/startup-running
