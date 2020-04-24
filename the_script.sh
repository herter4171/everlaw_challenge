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

#TODO: Validate number of input args!

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

# Send the Docker Compose config, then launch the web server if not running
scp_up docker-compose.yml
$SSH_PFX /bin/bash <<'EOF'
CTNOR_CT=$(docker container ls \
    | awk '{print $NF}' \
    | grep -c ubuntu_web_server_1)

# Need to make htdocs so it's not owned by root
if [[ $CTNOR_CT == 0 ]]; then 
    mkdir -p htdocs
    docker-compose up -d
fi

# Print for sanity check
docker container ls
EOF

#-----------------------------------------------------------------------------#
# CSV DOWNLOAD AND COLUMN PARSE
#-----------------------------------------------------------------------------#

# Get filename from tail-end of URL, and add spaces where applicable
CSV_FILE=$(echo ${CSV_URL##*/} | sed 's/%20/ /g')

# Download csv file if not already present
if [ ! -f "$CSV_FILE" ]; then 
    wget $CSV_URL
    sed -i 1d "$CSV_FILE" # Remove first line
else
    echo "$CSV_FILE already downloaded."
fi

# Get the desired column in a separate file
COL_FILE=col.txt
awk -F ',' -v col=$CSV_COL '{print $col}' "$CSV_FILE" > $COL_FILE

# Pre-emptively convert all spaces to %20
sed -i 's/ /%20/g' $COL_FILE

#-----------------------------------------------------------------------------#
# COLUMN DATA VALUE PARSING
#-----------------------------------------------------------------------------#

# Make sure a dir exists for text files and that it's empty
TXT_DIR=$PWD/txt_upload
mkdir -p $TXT_DIR
rm -rf $TXT_DIR/*

# Write counts of text
IFS=$'\n' 
for CURR_LN in $(cat $COL_FILE); do
    CURR_LN_FILE="$TXT_DIR/${CURR_LN}.txt"

    if [ ! -f $CURR_LN_FILE ]; then
        echo "Unique Val: $(echo "$CURR_LN" | sed 's/%20/ /g')"
        grep -c "$CURR_LN" col.txt > $CURR_LN_FILE
    fi
done