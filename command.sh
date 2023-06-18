#!/bin/bash

### RECEIVE COMMAND FROM THE API ###
### DO NOT MODIFY THIS FILE ###

# Configuration
source config.env
source params.env

# Common code
source common.sh

# Set API endpoint
COMMAND_ENDPOINT=${BASE_API}/commands

# Remember the script startup time
START_TIME=$(date +%s)
TIME_TO_RUN="${1:-60}"

execute_command() {
    local command_name="$1"
    local argument="$2"

    # Debug print 
    if [ "$LOCAL_DEBUG" = 1 ]; then
        echo "command: ${command_name}, argument: ${argument}"
        function request() { echo "$@"; }
    else
        function request() { curl -X POST "http://localhost:7654/$@"; }
    fi

    # Prepare the arguments and execute the command
    case "${command_name}" in
        "door_lock")
            local CMD="lock"
            [[ "$argument" == "1" ]] && CMD="lock" || CMD="unlock"

            request "door_${CMD}"
            ;;

        "sentry")
            local MODE="false"
            [[ "$argument" == "1" ]] && MODE="true" || MODE="false"

            request -d "{\"on\":${MODE}}" "set_sentry_mode"
            ;;

        "auto_conditioning")
            local CMD="stop"
            [[ "$argument" == "1" ]] && CMD="start" || CMD="stop"

            request "auto_conditioning_${CMD}"
            ;;

        "charging_limit")
            request "set_charge_limit?percent=${argument}"
            ;;

        "charging_amps")
            request "set_charging_amps?charging_amps=${argument}"
            ;;

        "charge_port")
            local CMD="close"
            [[ "$argument" == "1" ]] && CMD="open" || CMD="close"

            request "charge_port_door_${CMD}"
            ;;

        "charge")
            local CMD="stop"
            [[ "$argument" == "1" ]] && CMD="start" || CMD="stop"

            request "charge_${CMD}"
            ;;

        "trunk")
            request "actuate_trunk?which_trunk=rear"
            ;;

        "frunk")
            request "actuate_trunk?which_trunk=front"
            ;;
        
        *)
            # all other commands:
            # honk_horn, flash_lights, remote_start_drive, etc...
            request "${command_name}"
            ;;
    esac
}

# Function to calculate the remaining time to run
remaining_run_time() {
    END=$(date +%s)
    DIFF=$(( $TIME_TO_RUN - $END + $START_TIME ))
    echo $DIFF
}

# Check for new commands until the time to run is over
while (( $(remaining_run_time) > 0 )); do
    command=$(curl $CURL_OPTS \
                -s --max-time "$(remaining_run_time)" \
                -H "Authorization: Basic $BASIC_AUTH" \
                "${COMMAND_ENDPOINT}")

    # Save the exit code of curl
    status_code=$?

    # exit code 28 means we're timed out
    # exit not equals to 0 means something went wrong
    if (( status_code == 28 )); then 
        break 

    # Non-empty response received, parse it
    elif (( status_code == 0 )) && [[ -n "$command" ]]; then
        IFS=',' read -ra cmd_parts <<< "${command}"
        uuid="${cmd_parts[0]}"
        command_name="${cmd_parts[1]}"
        argument="${cmd_parts[2]}"
        received_hash="${cmd_parts[3]}"

        # Calculate the expected security hash
        expected_hash=$(echo -n "${uuid}${command_name}${argument}${PASSWORD}" | ${SHA256CMD} | awk '{ print $1 }')

        # Authorize the command request by comparing hashesh
        if [ "${received_hash}" != "${expected_hash}" ]; then
            continue
        fi

        # Execute the command and send a POST request
        #  to confirm tha command was accepted
        if execute_command "${command_name}" "${argument}"; then
            curl -s -X POST \
                 -H "Authorization: Basic $BASIC_AUTH" \
                 "${COMMAND_ENDPOINT}/${uuid}"
        fi
    fi

    # Sleep for 1 second before checking for new commands
    sleep 1
done

