#!/bin/bash

KLIPPER_REPO="https://github.com/Klipper3d/klipper.git"
declare -A BOARD_CONFIGS

for config_file in configs/*.config; do
    filename=$(basename "$config_file")
    key="${filename%.config}"
    BOARD_CONFIGS["$key"]="configs/$filename"
done

load_menuconfig() {
    config_file=$1
    cp "$config_file" .config
}

get_latest_klipper_version() {
    cd "klipper"
    git fetch --tags
    latest_tag=$(git describe --tags --always)
    cd ..
    echo "$latest_tag"
}


build_firmware() {
    board_config=$1
    output_path=$2
    
    make clean
    make
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname ../$output_path)"
    
    # Check if we need .uf2 or .bin
    if [[ "$output_path" == *".uf2" ]]; then
        # For RP2040 boards
        cp out/klipper.uf2 "../$output_path"
    else
        # For other boards
        cp out/klipper.bin "../$output_path"
    fi
}

main() {
    # Ensure we're in the script's directory
    cd "$(dirname "$0")"
    
    # Create necessary directories
    mkdir -p {configs,firmware_binaries}
    
    # Clone or update Klipper repository in build directory
    if [ ! -d "$KLIPPER_BUILD_DIR" ]; then
        git clone "$KLIPPER_REPO" "$KLIPPER_BUILD_DIR"
    else
        cd "$KLIPPER_BUILD_DIR"
        git fetch origin
        git reset --hard origin/master
        cd ..
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
        output_file="${BOARD_CONFIGS[$board]}"
        echo "Building for $board -> $output_file"
        
        cd "$KLIPPER_BUILD_DIR"
        
        # Load config if exists, otherwise create it
        if [ -f "../configs/$board.config" ]; then
            load_menuconfig "../configs/$board.config"
        else
            echo "No config found for $board. Please configure and save:"
            save_menuconfig "$board"
            continue
        fi
        
        # Build firmware
        build_firmware "$board" "$output_file"
        cd ..
    done
    
    # Cleanup
    echo "Cleaning up build directory..."
    rm -rf "$KLIPPER_BUILD_DIR"
    
    echo "Build process completed successfully!"
}


main