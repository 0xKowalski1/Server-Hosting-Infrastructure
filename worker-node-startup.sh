#!/bin/bash

touch /home/ubuntu/startup-running

# Update the system
sudo apt-get update

# Install Go
sudo apt-get install -y software-properties-common
sudo add-apt-repository ppa:longsleep/golang-backports
sudo apt-get update
sudo apt-get install -y golang-go

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

# create mounts/logs dirs
mkdir -p /home/ubuntu/mounts /home/ubuntu/logs

# Create config.json with specified configuration and updated external IP address

cat <<EOF >/home/ubuntu/config.json
{
  "namespace": "development",
  "nodeIp": "$(curl -s http://ifconfig.me)",
  "controlNodeIp": "${CONTROL_NODE_EXTERNAL_IP}",
  "containerdSocketPath": "/run/containerd/containerd.sock",
  "storagePath": "/home/ubuntu/mounts/",
  "cniPath": "/opt/cni/bin",
  "networkConfigPath": "/etc/cni/net.d",
  "networkConfigFileName": "mynet",
  "networkNamespacePath": "/var/run/netns/",
  "logPath": "/home/ubuntu/logs/"
}
EOF

echo "Config file created successfully with external IP."

# URL for the worker-node binary from GitHub Releases
WORKER_NODE_URL="https://github.com/0xKowalski1/container-orchestrator/releases/download/v0.0.1/worker-node"

# Use wget to download the binary
wget $WORKER_NODE_URL -O /home/ubuntu/worker-node

# Make the downloaded binary executable
chmod +x /home/ubuntu/worker-node

echo "worker-node downloaded and set as executable."

# Install Docker
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker

docker run -d -p 0.0.0.0:5000:5000  --restart=always --name registry registry:2

# Get container orchestrator
cd /home/ubuntu/
git clone https://github.com/0xKowalski1/container-orchestrator.git

# Push minecraft to registry
cd /home/ubuntu/container-orchestrator/container-examples/minecraft
sh pushToRegistry.sh




rm /home/ubuntu/startup-running
