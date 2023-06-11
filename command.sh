#!/bin/bash

### SEND METRICS TO THE API ###
### DO NOT MODIFY THIS FILE ###

# configuration
source config.env
source params.env

# common code
source common.sh

COMMAND_ENDPOINT=${BASE_API}/commands

# TODO: replace it with the argument
remaining_run_time=60

execute_command() {
    local command_name="$1"
    local argument="$2"

    # Debug print JSON
    if [ "$LOCAL_DEBUG" = 1 ]; then
        echo "command: ${command_name}, argument: ${argument}"
    fi

    case "${command_name}" in
        "door_lock")
            #echo "door lock command: ${argument}"
            ;;
        "set_charging_limit")
            curl "http://localhost:7654/set_charge_limit?percent=${argument}"
            ;;
        *)
            echo "Unknown command received: ${command_name}"
            return 1
            ;;
    esac
}

command=$(curl $CURL_OPTS \
            -s --max-time "${remaining_run_time}" \
            -H "Authorization: Basic $BASIC_AUTH" \
            "${COMMAND_ENDPOINT}")

# check if curl failed
if [ $? -ne 0 ]; then
    echo "/commands request failed, exiting"
    exit 1
else
    # Response received, parse it and execute the command
    IFS=',' read -ra cmd_parts <<< "${command}"
    uuid="${cmd_parts[0]}"
    command_name="${cmd_parts[1]}"
    argument="${cmd_parts[2]}"
    received_hash="${cmd_parts[3]}"

    # Calculate the expected hash
    expected_hash=$(echo -n "${uuid}${PASSWORD}" | ${SHA256CMD} | awk '{ print $1 }')

    # Check if the received hash matches the expected hash
    if [ "${received_hash}" == "${expected_hash}" ]; then
    # Execute the command and check if it successed
        if execute_command "${command_name}" "${argument}"; then
            # Send a POST request to the API with the UUID appended to the URL
            curl -s -X POST \
                 -H "Authorization: Basic $BASIC_AUTH" \
                 "${COMMAND_ENDPOINT}/${uuid}"
        fi
    else
        echo "Invalid hash received."
        exit 2
    fi
fi


