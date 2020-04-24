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
# COMMONLY USED VARS/FUNCS AND INIT
#-----------------------------------------------------------------------------#

# Set names for args to make things readable
EC2_IP=$1; PRIV_KEY=$2; CSV_URL=$3; CSV_COL=$4

# Shorten SSH commands and assume remote username is "ubuntu"
SSH_PFX="ssh -i $PRIV_KEY ubuntu@$EC2_IP"

# Single arg wrapper for sending things via SCP to /home/ubuntu on remote
scp_up() {
    scp -i $PRIV_KEY $1 ubuntu@$EC2_IP:/home/ubuntu
}

# Make sure we can connect to the remote and exit gracefully if not
$SSH_PFX echo 'Hello from $HOSTNAME'
if [[ $? != 0 ]]; then echo "Failed to connect to $2"; exit 0; fi

#-----------------------------------------------------------------------------#
# DOCKER SETUP
#-----------------------------------------------------------------------------#

# Make sure Docker and docker-compose are installed on the remote
$SSH_PFX sudo /bin/bash <<'EOF'
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
EOF

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

# Make sure empty htdocs dir, and print containers for sanity check
rm -rf htdocs/*
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
# COLUMN DATA VALUE PARSING AND UPLOAD
#-----------------------------------------------------------------------------#

# Make sure a dir exists for text files and that it's empty
TXT_DIR=$PWD/txt_upload
mkdir -p $TXT_DIR
rm -rf $TXT_DIR/*

# Write counts of text
IFS=$'\n' 
for CURR_LN in $(cat $COL_FILE); do
    CURR_LN_FILE="$TXT_DIR/${CURR_LN}.txt"

    # Write count to file if not already written
    if [ ! -f $CURR_LN_FILE ]; then
        echo "Unique Val: $(echo "$CURR_LN" | sed 's/%20/ /g')"
        grep -c "$CURR_LN" col.txt > $CURR_LN_FILE
    fi
done

# Upload test files to the remote's htdocs folder
cd $TXT_DIR
scp -i $PRIV_KEY *.txt ubuntu@$EC2_IP:/home/ubuntu/htdocs
cd ..