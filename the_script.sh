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
# INITIAL SETUP
#-----------------------------------------------------------------------------#

# Set names for args to make things readable
EC2_IP=$1; PRIV_KEY=$2; CSV_URL=$3; CSV_COL=$4

# Shorten SSH commands and assume remote username is "ubuntu"
SSH_PFX="ssh -i $PRIV_KEY ubuntu@$EC2_IP"

# Make sure we can connect to the remote and exit gracefully if not
$SSH_PFX echo 'Hello from $HOSTNAME'
if [[ $? != 0 ]]; then echo "Failed to connect to $2"; exit 0; fi