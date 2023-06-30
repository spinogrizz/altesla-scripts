#!/bin/bash

INSTALL_FILE="install.tar"
INSTALLER_URL="install.altesla.app"
INSTALL_DIR="/home/.altesla"

GR='\033[1;32m'; RD='\033[1;31m'; NC='\033[0m'
STEP=1; TOTAL=7

function echo_step { echo -e "${GR}[$STEP/$TOTAL]${NC} $1"; STEP=$((STEP+1)); }
function echo_error { echo -e "${RD}Error: $1${NC}"; exit 1; }
function read_input { read -p "- $1: " input </dev/tty; echo $input; }
function ask_user() { 
    while true; do read -p "${1} (y/n) " yn; case $yn in
        [Yy]* ) echo 1; return;;
        [Nn]* ) echo 0; return;;
        * ) echo "Answer Y or N.";
    esac; done
}

# Choose the sed command based on the OS (macOS is weird)
[[ $(uname) == "Darwin" ]] && SED_CMD="sed -i \"\"" || SED_CMD="sed -i"

# Creating installation directory (only on Linux)
if [[ $(uname) != "Darwin" ]]; then
    echo_step "Creating installation ${INSTALL_DIR} directory..."
    mkdir -p ${INSTALL_DIR} || { echo_error "Failed to create ${INSTALL_DIR}"; }
    cd ${INSTALL_DIR}
fi

# Download the package
echo_step "Downloading the package..."
curl -Osf ${INSTALLER_URL}/${INSTALL_FILE} || { echo_error "Failed to download ${INSTALL_FILE}"; }

# Unpack it into the current folder
echo_step "Unpacking the ${INSTALL_FILE}..."
tar -xf ${INSTALL_FILE} || { echo_error "Failed to unpack ${INSTALL_FILE}"; }

# Create a config.env file using config.env.example file in that tarball
echo_step "Creating config.env file..."
cp config.env.example config.env

# PASSWORD
#password=$(read_input "Enter the password for the car")
while true; do
    password1=$(read_input "Create new password for accessing the car")
    password2=$(read_input "Confirm new password")
    if [[ $password1 == $password2 ]]; then
        eval $SED_CMD "s~^PASSWORD=.*~PASSWORD=\"$password1\"~g" config.env
        break
    else
        echo -e "${RD}Passwords do not match. Please try again.${NC}"
    fi
done


# OTA_UPDATES
answer=$(ask_user "Do you wish to enable automatic OTA updates?")
eval $SED_CMD "s~^OTA_UPDATES=.*~OTA_UPDATES=$answer~g" config.env

# INTERVAL
while true; do
    interval=$(read_input "Choose update interval (20-300 seconds, default: 60)")
    if [[ $interval =~ ^[0-9]+$ ]] && ((interval >= 20 && interval <= 300)); then
        break
    elif [[ -z "$interval" ]]; then
        interval=60
        break
    else
        echo "Please enter a valid interval (20-300)."
    fi
done

eval $SED_CMD "s~^INTERVAL=.*~INTERVAL=$interval~g" config.env

# Fixing permissions
echo_step "Fixing permissions..."
chmod +x *.sh

# Remove the installation file
echo_step "Cleaning up..."
rm $INSTALL_FILE

# Run the send metrics script to test the configuration
answer=$(ask_user "Do you wish to run the test script now?")
if [[ $answer == 1 ]]; then
    echo_step "Running send.sh script to test connectivity..."
    bash send.sh -f || { echo_error "Failed to send metrics to the server"; }
else
    TOTAL=$((TOTAL-1));
fi

echo ""

# Output the final instruction to the user
echo_step "Installation completed. Please read the following: "

cat << EOF
    1. You may edit config.env file to access advanced settings.
    2. Run ./main.sh to check that script runs, sleeps for ${interval} seconds.
    3. Open up https://api.altesla.app/check/$(cat /var/etc/vin)
    4. Check that webpage flashes green every ${interval} seconds or when ./send.sh is run.
    5. Add ./main.sh to crontab to run it every minute
    
    If you are using poorcron.sh implementation, add following line to the loop,
    and remove "sleep 60" line, as it is not needed anymore:

       cd /home/.altesla && bash main.sh && cd

    If OTA updates are enabled, the scripts will check and automatically update
    every other night at 4:00 AM. You can also update manually:

       $ ./update.sh -f

EOF

