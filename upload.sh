#!/bin/bash
source config.env
source common.env
source libs/json.sh

# List of params to filter from the 'ldvs' output
params=(
    # battery state
    "BMS_state"                      # charging or not
    "BMS_hvState"                    # hv battery state
    "SOC"                            # battery charge level

    # battery health
    "BMS_nominalFullPackEnergy"      # battery capacity (current)
    "BMS_beginningOfLifePackEnergy"  # battery capacity (from factory)

    # doors
    "is_locked"                      # doors are locked or not

    # car stats
    "odo"                            # odometer value
    "speed"                          # current speed

    # location
    "nav_lat"                        # gps latitude
    "nav_lon"                        # gps longitude

    # tires
    "last_seen_tpms_pressure_fl"     # tire pressure front left
    "last_seen_tpms_pressure_fr"     # tire pressure front right
    "last_seen_tpms_pressure_rl"     # tire pressure rear left
    "last_seen_tpms_pressure_rr"     # tire pressure rear right

    # climate
    "VCRIGHT_hvacACRunning"          # AC is on or not
    "VCRIGHT_hvacPowerState"         # Climate is on or not
    "VCRIGHT_hvacCabinTempEst"       # Cabin temperature
    "VCFRONT_tempAmbient"            # Outside temperature
    "VCRIGHT_hvacBlowerSegment"      # Fan speed

    # charging stats
    "BMS_acChargerKwhTotal"          # total kWh charged with AC
    "BMS_dcChargerKwhTotal"          # total kWh charged with DC
    "BMS_kwhRegenChargeTotal"        # total kWh regenerated
    "BMS_chgPowerAvailable"          # max charging power available (kWh)
    "kwh_chg_counter"                # kWh charged since last charge
)

# Construct the grep command for filtering params
filter="grep -E \"^("
for i in "${!params[@]}"; do
  filter+="${params[$i]}"
  if [ $i -lt $((${#params[@]}-1)) ]; then
    filter+="|"
  fi
done
filter+=")\""

# Filter the output of 'ldvs' command and store the filtered lines in a variable
ldvs_output=$($ldvs | eval "$filter")

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
done <<< "$ldvs_output"
json+="}"

# Debug print JSON
if [ "$LOCAL_DEBUG" = 1 ]; then
  echo $json
fi

# Calculate basic http auth using sha256 hash of vincode+password
BASIC_AUTH=$(base64 <<< "$VINCODE:$PASSWORD" | awk '{print $1}')

# Send the JSON document as a POST request 
# to the metrics endpoint, appending the VIN code to the URL
curl $CURL_OPTS -X POST \
     -H "Content-Type: application/json" \
     -H "Authorization: Basic $BASIC_AUTH" \
     -d "$json" \
     $METRICS_ENDPOINT



