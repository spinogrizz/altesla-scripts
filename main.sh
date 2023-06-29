#!/bin/bash

# configuration
source config.env
source params.env

# common code
source common.sh

# Remember the script startup time
START_TIME=$(date +%s)

# Check if lockfile exists
if [ -e "${LOCKFILE}" ]; then
  echo "Lockfile exists, script is already running."
  exit 1
else
  touch "${LOCKFILE}"
fi

# Function to cleanup on script exit
cleanup() {
    rm -f ${LOCKFILE}    
}

# Trap any form of script exit
trap cleanup EXIT

# send metrics to the API
bash send.sh

# Calculate remaining time left to run
NOW=$(date +%s)
REMAINING_TIME=$(( $INTERVAL - $NOW + $START_TIME ))

# wait and execute commands from the API
bash command.sh $REMAINING_TIME

# check for OTA updates, if enabled
if [ "$OTA_UPDATES" = 1 ]; then
  bash update.sh
fi