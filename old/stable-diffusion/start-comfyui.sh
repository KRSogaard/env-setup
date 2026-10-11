#!/bin/bash
cd "$(dirname "$0")/ComfyUI"
echo "🚀 Starting ComfyUI..."
echo "📍 Directory: $(pwd)"
echo "🌐 Will be available at: http://localhost:8188"
echo ""
source venv/bin/activate
python main.py --listen --port 8188 