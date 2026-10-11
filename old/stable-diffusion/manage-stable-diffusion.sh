#!/bin/bash

show_help() {
    echo "🎨 Stable Diffusion Management Script"
    echo ""
    echo "Usage: $0 <command> [service]"
    echo ""
    echo "Commands:"
    echo "  start <service>  - Start a service"
    echo "  stop <service>   - Stop a service (Ctrl+C in terminal)"
    echo "  status          - Show running processes"
    echo "  update          - Update repositories"
    echo "  help            - Show this help"
    echo ""
    echo "Services:"
    echo "  auto   - Automatic1111 WebUI"
    echo "  comfy  - ComfyUI"
    echo ""
    echo "Examples:"
    echo "  $0 start auto   # Start Automatic1111"
    echo "  $0 start comfy  # Start ComfyUI"
    echo "  $0 status       # Show what's running"
    echo "  $0 update       # Update both repositories"
}

case "$1" in
    start)
        case "$2" in
            auto|automatic1111)
                echo "🚀 Starting Automatic1111..."
                ./start-automatic1111.sh
                ;;
            comfy|comfyui)
                echo "🚀 Starting ComfyUI..."
                ./start-comfyui.sh
                ;;
            *)
                echo "❌ Please specify a service: auto or comfy"
                show_help
                exit 1
                ;;
        esac
        ;;
    stop)
        echo "⏹️  To stop services, use Ctrl+C in their terminal windows"
        echo "Or find and kill the processes:"
        echo "  pkill -f 'webui.sh'"
        echo "  pkill -f 'main.py.*ComfyUI'"
        ;;
    status)
        echo "📊 Checking running processes..."
        echo ""
        echo "Automatic1111 processes:"
        pgrep -f "webui.sh" > /dev/null && echo "  ✅ Running" || echo "  ❌ Not running"
        echo ""
        echo "ComfyUI processes:" 
        pgrep -f "main.py.*ComfyUI" > /dev/null && echo "  ✅ Running" || echo "  ❌ Not running"
        ;;
    update)
        echo "🔄 Updating repositories..."
        if [ -d "automatic1111" ]; then
            echo "Updating Automatic1111..."
            cd automatic1111
            git pull
            cd ..
        fi
        if [ -d "ComfyUI" ]; then
            echo "Updating ComfyUI..."
            cd ComfyUI  
            git pull
            cd ..
        fi
        echo "✅ Updates completed!"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ Unknown command: $1"
        show_help
        exit 1
        ;;
esac 