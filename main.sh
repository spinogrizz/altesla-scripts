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
    # Remove lockfile
    rm -f ${LOCKFILE}
    
    # # Calculate the remaining time and sleep the rest of the interval
    # TIME_REMAINING=$(remaining_run_time)
    # if (( TIME_REMAINING > 0 )); then
    #     sleep $TIME_REMAINING
    # fi
}

remaining_run_time() {
    END=$(date +%s)
    DIFF=$(( $INTERVAL - $END + $START_TIME ))
    echo $DIFF
}

# Trap any form of script exit
trap cleanup EXIT

bash send.sh       # send metrics to the API
bash command.sh    # wait and execute commands from the API
