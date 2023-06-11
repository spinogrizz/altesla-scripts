#!/bin/bash

# configuration
source config.env
source params.env

# common code
source libs/json.sh
source common.sh

START_TIME=$(date +%s)

# Function to cleanup on script exit
cleanup() {
    # Remove lockfile
    rm -f ${LOCKFILE}
    
    # Calculate the remaining time and sleep the rest of the interval
    TIME_REMAINING=$(remaining_run_time)
    if (( TIME_REMAINING > 0 )); then
        sleep $TIME_REMAINING
    fi
}

remaining_run_time() {
    END=$(date +%s)
    DIFF=$(( $INTERVAL - $END + $START ))
    echo $DIFF
}

# Trap any form of script exit
trap cleanup EXIT

get_params() {
  local filter="grep -E \"^("

  local idx=0
  for param in "$@"; do
    filter+="$param"
    if [ $idx -lt $(($#-1)) ]; then
      filter+="|"
    fi
    idx=$((idx+1))
  done

  filter+="),\""

  # Filter the output of 'ldvs' command and return the filtered lines
  printf "%s\n" "$($ldvs | eval "$filter")"
}

# update different parameters with a different frequency
params_output=""
hour=$(date +%H)
minute=$(date +%M)

if [ $hour == "23" ] && [ $minute == "59" ]; then
  params_output+=$(get_params "${fast_params[@]}" "${slow_params[@]}" "${eventual_params[@]}")
elif [ $((minute % 5)) == 0 ]; then
  params_output+=$(get_params "${fast_params[@]}" "${slow_params[@]}")
else
  params_output+=$(get_params "${fast_params[@]}")
fi

# Check if ldvs/grep command exited successfully before proceeding
if [ $? -ne 0 ]; then
  echo "Error: ldvs command failed."
  exit 1
fi

# Generate the JSON document
json="{"
first=true
while IFS=',' read -ra line; do
  key="${line[0]}"
  value="${line[1]}"

  if [ "$first" = true ]; then
    first=false
  else
    json+=", "
  fi
  json+=$(line2json "$key" "$value")
done <<< "$params_output"
json+="}"

# Debug print JSON
if [ "$LOCAL_DEBUG" = 1 ]; then
  echo $json
fi

# Send the JSON document as a POST request, to the metrics endpoint
curl $CURL_OPTS -X POST \
     -H "Content-Type: application/json" \
     -H "Authorization: Basic $BASIC_AUTH" \
     -d "$json" \
     $METRICS_ENDPOINT

