#!/bin/bash

#-----------------------------------------------------------------------------#
# Author: Justin Herter
#
# Input Arguments: 
#   $1: IP address of EC2 instance to operate on
#   $2: Path to the private SSH key for connecting to $1
#   $3: URL to a public *.csv file for parsing
#   $4: Column number to parse in $3
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# COMMONLY USED VARS/FUNCS
#-----------------------------------------------------------------------------#

# Set names for args to make things readable
EC2_IP=$1; PRIV_KEY=$2; CSV_URL=$3; CSV_COL=$4

# Shorten SSH commands and assume remote username is "ubuntu"
SSH_PFX="ssh -i $PRIV_KEY ubuntu@$EC2_IP"

# Single arg wrapper for sending things via SCP to /home/ubuntu on remote
scp_up() {
    scp -i $PRIV_KEY $1 ubuntu@$EC2_IP:/home/ubuntu
}

#-----------------------------------------------------------------------------#
# DOCKER SETUP
#-----------------------------------------------------------------------------#

# Make sure we can connect to the remote and exit gracefully if not
$SSH_PFX echo 'Hello from $HOSTNAME'
if [[ $? != 0 ]]; then echo "Failed to connect to $2"; exit 0; fi

# Send Docker install script up to remote, then run it
scp_up install_docker.sh
$SSH_PFX sudo /bin/bash install_docker.sh
