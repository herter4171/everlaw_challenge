#!/bin/bash

#-----------------------------------------------------------------------------#
# AUTHOR: Justin Herter
#
# FUNCTIONALITY:  The end state from running this is an Apache Web Server on
# the given remote EC2 instance that has values for a given column as pages
# that contain the number of occurences of said value in the column.  Setting
# this up involves ensuring Docker and Docker Compose are installed on the
# remote followed by launching the web server, obtaining the csv file, and 
# parsing the user-specified column.  
#
# INPUT VALIDATION: The first check is ensuring exactly 4 arguments have been
# supplied.  This is followed by ensuring a viable SSH pathway, which confirms 
# the supplied keyfile and remote IP are valid.  From there, the URL is checked 
# to ensure it has the csv extension.  Last of all is ensuring the column 
# number is in bounds. 
#
# INPUT ARGUMENTS: 
#   $1: IP address of EC2 instance to operate on
#   $2: Path to the private SSH key for connecting to $1
#   $3: URL to a public *.csv file for parsing
#   $4: Column number to parse in $3
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# COMMONLY USED VARS/FUNCS AND INIT
#-----------------------------------------------------------------------------#

# Validate argument count, and print input arg spec if wrong count
if [[ $# != 4 ]]; then 
    echo "ERROR: Expect four arguments.  See arg list below."
    grep -A 4 "^# INPUT ARGUMENTS:" $0
    exit 1
fi

# Set names for args to make things readable
EC2_IP=$1; PRIV_KEY=$2; CSV_URL=$3; CSV_COL=$4

# Shorten SSH commands and assume remote username is "ubuntu"
SSH_PFX="ssh -i $PRIV_KEY ubuntu@$EC2_IP"

# Make sure we can connect to the remote and exit gracefully if not
$SSH_PFX echo 'Hello from $HOSTNAME'
if [[ $? != 0 ]]; then echo "Failed to connect to $2"; exit 1; fi

# Make sure given URL is *.csv
if [[ $(echo $CSV_URL | grep -c .csv$) == 0 ]]; then
    echo "ERROR: URL doesn't appear to point to a csv file."
    echo "Given URL is \"$CSV_URL\""
    exit 1
fi

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

# Start on boot (likely overkill for this task)
systemctl enable docker

# Install Docker Compose and set +x perms
curl -L "https://github.com/docker/compose/releases/download/1.25.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Indicate done installing Docker things
echo "Installed Docker and Docker Compose"
EOF

# Print and upload a Docker Compose config for an Apache Web Server
printf \
"version: '3'
services:
  web_server:
    image: httpd
    ports:
      - 80:80
    volumes:
      - /home/ubuntu/htdocs:/usr/local/apache2/htdocs
" > docker-compose.yml
scp -i $PRIV_KEY docker-compose.yml ubuntu@$EC2_IP:/home/ubuntu

# Send the Docker Compose config, then launch the web server if not running
$SSH_PFX /bin/bash <<'EOF'
CTNOR_CT=$(docker container ls \
    | awk '{print $NF}' \
    | grep -c ubuntu_web_server_1)

# Need to make htdocs so it's not automatically made and owned by root
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

# Get number of cols from first line comma count plus one
NUM_COLS=$((`head -n 1 "$CSV_FILE" | tr -cd , | wc -c`+1))
echo "NUM_COLS: $NUM_COLS"

# Validate column index from args
if [ $CSV_COL -lt 1 ] || [ $CSV_COL -gt $NUM_COLS ]; then
    echo "ERROR: Column arg must be between 1 and $NUM_COLS for \"$CSV_FILE\""
    exit 1
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

# Do a test curl on one of the files for a sanity check
TEST_FILE=$(ls | head -n 1)
echo "Performing test curl for $TEST_FILE"
echo "Result: $(curl http://$EC2_IP/$TEST_FILE)"