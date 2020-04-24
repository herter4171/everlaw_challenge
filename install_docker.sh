#!/bin/bash

#-----------------------------------------------------------------------------#
# Author: Justin Herter
# Usage: Run to install Docker and Docker Compose on Ubuntu 18.04
#-----------------------------------------------------------------------------#

# Don't need to run through all of this if already installed
if [[ -f $(which docker) ]] && [[ -f $(which docker-compose) ]]; then
    echo "Docker and Docker Compose are already installed."
    exit 0
fi

# Update package lists
apt-get update -y

# Install packages
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Add Docker repo
add-apt-repository -y \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# Update package lists now that Docker repo is added
apt-get update -y

# Install Docker components
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io

# Create Docker group and add default user "ubuntu"
groupadd docker
usermod -aG docker ubuntu

# Start on boot
systemctl enable docker

# Install Docker Compose and set +x perms
curl -L "https://github.com/docker/compose/releases/download/1.25.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Indicate done installing Docker things
echo "Installed Docker and Docker Compose"