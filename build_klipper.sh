#!/bin/bash

set -e  # Exit on any error

KLIPPER_REPO="https://github.com/Klipper3d/klipper.git"
KLIPPER_BUILD_DIR="$(pwd)/klipper"
FIRMWARE_OUTPUT_DIR="$(pwd)/firmware_binaries"
declare -A BOARD_CONFIGS

# Initialize board configs
for config_file in configs/*.config; do
    filename=$(basename "$config_file")
    key="${filename%.config}"
    BOARD_CONFIGS["$key"]="configs/$filename"
done

load_menuconfig() {
    config_file=$1
    echo "Loading config from: $config_file"
    cp "$config_file" .config
}

get_latest_klipper_version() {
    cd "$KLIPPER_BUILD_DIR"
    git fetch --tags
    latest_tag=$(git describe --tags --always)
    cd - > /dev/null
    echo "$latest_tag"
}

build_firmware() {
    board_config=$1
    output_path=$2
    
    echo "Building firmware with config: $board_config"
    echo "Output path will be: $output_path"
    
    make clean
    make
    
    # Create directory if it doesn't exist
    mkdir -p "$FIRMWARE_OUTPUT_DIR"
    
    # Check if we need .uf2 or .bin
    if [[ "$board_config" == *"pico"* ]]; then
        # For RP2040 boards
        cp out/klipper.uf2 "$FIRMWARE_OUTPUT_DIR/${board_config}.uf2"
    else
        # For other boards
        cp out/klipper.bin "$FIRMWARE_OUTPUT_DIR/${board_config}.bin"
    fi
}

main() {
    # Ensure we're in the script's directory
    cd "$(dirname "$0")"
    SCRIPT_DIR="$(pwd)"
    
    # Create or clean firmware output directory
    mkdir -p "$FIRMWARE_OUTPUT_DIR"
    rm -rf "${FIRMWARE_OUTPUT_DIR:?}"/*
    
    echo "Current directory: $(pwd)"
    echo "Klipper build directory will be: $KLIPPER_BUILD_DIR"
    
    # Clone or update Klipper repository
    if [ ! -d "$KLIPPER_BUILD_DIR" ]; then
        echo "Cloning Klipper to $KLIPPER_BUILD_DIR"
        git clone "$KLIPPER_REPO" "$KLIPPER_BUILD_DIR"
    else
        echo "Updating existing Klipper repository"
        cd "$KLIPPER_BUILD_DIR"
        git fetch origin
        git reset --hard origin/master
        cd "$SCRIPT_DIR"
    fi
    
    # Get latest version
    latest_version=$(get_latest_klipper_version)
    echo "Latest Klipper version: $latest_version"
    
    # Output board list to a file for the release notes
    echo "Building firmware for the following boards:" > board_list.txt
    for board in "${!BOARD_CONFIGS[@]}"; do
        echo "- $board" >> board_list.txt
    done
    
    cat board_list.txt
    
    # Build for each board
    for board in "${!BOARD_CONFIGS[@]}"; do
        echo "Processing board: $board"
        config_file="${BOARD_CONFIGS[$board]}"
        echo "Config file: $config_file"
        
        if [ ! -f "$config_file" ]; then
            echo "Error: Config file not found: $config_file"
            continue
        fi
        
        cd "$KLIPPER_BUILD_DIR"
        
        echo "Loading config for $board"
        load_menuconfig "../$config_file"
        
        echo "Building firmware for $board"
        build_firmware "$board" "$FIRMWARE_OUTPUT_DIR/$board"
        
        cd "$SCRIPT_DIR"
    done
    
    echo "Build process completed!"
}

main