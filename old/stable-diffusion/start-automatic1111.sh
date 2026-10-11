#!/bin/bash
cd "$(dirname "$0")/automatic1111"
echo "🚀 Starting Automatic1111 WebUI..."
echo "📍 Directory: $(pwd)"
echo "🌐 Will be available at: http://localhost:7860"
echo ""
source venv/bin/activate
./webui.sh --listen --enable-insecure-extension-access --xformers --skip-python-version-check 