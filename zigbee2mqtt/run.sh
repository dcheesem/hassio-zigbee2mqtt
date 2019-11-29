#!/bin/bash

CONFIG_PATH=/data/options.json

DATA_PATH=$(jq --raw-output ".data_path" $CONFIG_PATH)
ZIGBEE_SHEPHERD_DEBUG=$(jq --raw-output ".zigbee_shepherd_debug // empty" $CONFIG_PATH)
ZIGBEE_SHEPHERD_DEVICES=$(jq --raw-output ".zigbee_shepherd_devices // empty" $CONFIG_PATH)
ZIGBEE_SHEPHERD_CONVERT_TO=$(jq --raw-output ".zigbee_shepherd_convert_to // empty" $CONFIG_PATH)
ZIGBEE_SHEPHERD_CONVERT_FROM=$(jq --raw-output ".zigbee_shepherd_convert_from // empty" $CONFIG_PATH)
ZIGBEE_DISCOVER=$(jq --raw-output ".zigbee_discover // empty" $CONFIG_PATH)

# Check if config exists already
mkdir -p $DATA_PATH
if [[ -f $DATA_PATH/configuration.yaml ]]; then
    if [[ ! -f $DATA_PATH/.configuration.yaml.bk ]]; then
        echo "[Info] Configuration file found in data path, but no backup file found in data path. Backing up existing configuration to ${DATA_PATH}/.configuration.yaml.bk"
        cp $DATA_PATH/configuration.yaml $DATA_PATH/.configuration.yaml.bk
    else
        "[Info] Configuration backup found in ${DATA_PATH}/.configuration.yaml.bk. Skipping config backup."
    fi
fi

#
# Override a file with a local copy from DATA_PATH
override_file() {
    local testFlag=$1
    local filename=$2
    local destPath=$3

    if [[ ! -z "$testFlag" ]]; then
        echo "[Info] Searching for custom $filename file in zigbee2mqtt data path..."
    
    	if [[ -f "$DATA_PATH"/"$filename" ]]; then
            cp -f "$DATA_PATH"/"$filename" "$destPath"/"$filename"
        else
            echo "[Error] File $DATA_PATH/$filename not found! Starting with default $filename"
        fi
    fi

}

# Parse config
cat "$CONFIG_PATH" | jq 'del(.data_path)' | jq 'del(.zigbee_shepherd_debug)' | jq 'del(.zigbee_shepherd_devices)' | jq 'del(.socat)' > $DATA_PATH/configuration.yaml

if [[ ! -z "$ZIGBEE_SHEPHERD_DEBUG" ]]; then
    echo "[Info] Zigbee Shepherd debug logging enabled."
    export DEBUG="zigbee-shepherd*"
fi

override_file "$ZIGBEE_SHEPHERD_DEVICES" "devices.js" "./node_modules/zigbee-herdsman-converters"
override_file "$ZIGBEE_SHEPHERD_CONVERT_TO" "toZigbee.js" "./node_modules/zigbee-herdsman-converters/converters"
override_file "$ZIGBEE_SHEPHERD_CONVERT_FROM" "fromZigbee.js" "./node_modules/zigbee-herdsman-converters/converters"
override_file "$ZIGBEE_DISCOVER" "homeassistant.js" "./lib/extension"

# FORK SOCAT IN A SEPARATE PROCESS IF ENABLED
SOCAT_EXEC="$(dirname $0)/socat.sh"
$SOCAT_EXEC $CONFIG_PATH

# RUN zigbee2mqtt
ZIGBEE2MQTT_DATA="$DATA_PATH" pm2-runtime start npm -- start
