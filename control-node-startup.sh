#!/bin/bash

# Update and install etcd server (not just the client)
sudo apt-get update
sudo apt-get install -y etcd

# The following settings are basic; you should modify them according to your cluster setup requirements

# Set up the etcd service to run on startup
sudo systemctl enable etcd

# Configure etcd server
ETCD_NAME=$(hostname)
INTERNAL_IP=$(curl http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip -H "Metadata-Flavor: Google")

cat <<EOF | sudo tee /etc/default/etcd
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="http://$INTERNAL_IP:2380"
ETCD_LISTEN_CLIENT_URLS="http://$INTERNAL_IP:2379,http://127.0.0.1:2379"
ETCD_NAME="$ETCD_NAME"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://$INTERNAL_IP:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://$INTERNAL_IP:2379"
ETCD_INITIAL_CLUSTER="$ETCD_NAME=http://$INTERNAL_IP:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF

# Restart etcd to apply configuration
sudo systemctl restart etcd

