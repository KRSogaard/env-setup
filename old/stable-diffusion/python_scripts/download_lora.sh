#!/bin/bash

# Civitai LoRA Downloader Wrapper Script
# Usage: ./download_lora.sh <civitai_url>

# Check if URL is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <civitai_url>"
    echo "Example: $0 'https://civitai.com/models/1256683/disney-animation-illustrious-and-pony?modelVersionId=1416874'"
    echo "Example: $0 '@https://civitai.com/models/1256683/disney-animation-illustrious-and-pony?modelVersionId=1416874'"
    exit 1
fi

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if virtual environment exists, create if not
if [ ! -d "$SCRIPT_DIR/venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$SCRIPT_DIR/venv"
fi

# Activate virtual environment
source "$SCRIPT_DIR/venv/bin/activate"

# Install requirements if not already installed
if [ ! -f "$SCRIPT_DIR/venv/.installed" ]; then
    echo "Installing requirements..."
    pip install -r "$SCRIPT_DIR/requirements.txt"
    touch "$SCRIPT_DIR/venv/.installed"
fi

# Run the downloader
echo "Starting LoRA download..."
python3 "$SCRIPT_DIR/civitai_lora_downloader.py" "$1"

echo "Done!" 