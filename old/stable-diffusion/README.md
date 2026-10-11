# Stable Diffusion Native Setup

This directory contains the native installation setup for Stable Diffusion Automatic1111 and ComfyUI.

## Quick Start

### Start Services
```bash
# Start Automatic1111 (Web UI at http://localhost:7860)
./start-automatic1111.sh

# Start ComfyUI (Web UI at http://localhost:8188)
./start-comfyui.sh

# Or use the management script
./manage-stable-diffusion.sh start auto    # Start Automatic1111
./manage-stable-diffusion.sh start comfy   # Start ComfyUI
```

### Stop Services
```bash
# Use Ctrl+C in the terminal windows where services are running
# Or kill the processes:
pkill -f 'webui.sh'           # Stop Automatic1111
pkill -f 'main.py.*ComfyUI'   # Stop ComfyUI

# Or use the management script
./manage-stable-diffusion.sh stop
```

### Management Commands
```bash
./manage-stable-diffusion.sh status    # Check service status
./manage-stable-diffusion.sh update    # Update repositories
./manage-stable-diffusion.sh help      # Show help
```

## Directory Structure

- `automatic1111/` - Automatic1111 WebUI installation
  - `venv/` - Python virtual environment
  - `models/` - Symlinked to shared models directory
- `ComfyUI/` - ComfyUI installation
  - `venv/` - Python virtual environment  
  - `models/` - Symlinked to shared models directory
- `models/` - Shared models directory
  - `Stable-diffusion/` - Stable Diffusion checkpoint models (.safetensors/.ckpt)
  - `VAE/` - VAE models
  - `Lora/` - LoRA models
  - `ControlNet/` - ControlNet models
- `outputs/` - Generated images and outputs

## Web Interfaces

- **Automatic1111**: http://localhost:7860
- **ComfyUI**: http://localhost:8188

## Installing Models

### Download Models
1. Download models from sources like:
   - [Hugging Face](https://huggingface.co/models)
   - [Civitai](https://civitai.com/)
   - [Stability AI](https://platform.stability.ai/)

2. Place models in the appropriate `models/` subdirectory:
   - **Stable Diffusion models** (.safetensors/.ckpt) → `models/Stable-diffusion/`
   - **VAE models** → `models/VAE/`
   - **LoRA models** → `models/Lora/`
   - **ControlNet models** → `models/ControlNet/`

3. Restart the services to load new models

### Shared Models
Both Automatic1111 and ComfyUI share the same models via symlinks, so you only need to download each model once.

## System Requirements

- **GPU**: NVIDIA GPU with CUDA support
- **RAM**: 8GB+ (16GB+ recommended)
- **Storage**: 20GB+ free space for models
- **Python**: 3.8+
- **CUDA**: 11.8+ or 12.1+

## Updating

### Update Installation
Run the installation script again to update configurations:
```bash
~/workspace/arch-setup/install-stable-diffusion.sh
```

### Update Repositories
```bash
./manage-stable-diffusion.sh update
```

## Troubleshooting

### GPU Issues
- Ensure NVIDIA drivers are installed: `nvidia-smi`
- Install CUDA toolkit: `sudo pacman -S cuda cudnn`
- Check Python can access GPU: `python -c "import torch; print(torch.cuda.is_available())"`

### Python Environment Issues
- Activate virtual environment: `source automatic1111/venv/bin/activate` or `source ComfyUI/venv/bin/activate`
- Reinstall dependencies: `pip install -r requirements.txt`

### Port Conflicts
- Check if ports are in use: `lsof -i :7860` or `lsof -i :8188`
- Kill conflicting processes or change port in startup scripts

### Performance Issues
- Close other GPU-intensive applications
- Reduce image resolution or batch size
- Use `--medvram` or `--lowvram` flags in startup scripts for low memory systems

## Advanced Configuration

### Custom Arguments
Edit the startup scripts to add custom arguments:
- `start-automatic1111.sh`: Modify the `./webui.sh` line
- `start-comfyui.sh`: Modify the `python main.py` line

### Extensions
- Automatic1111 extensions: Install via the web UI Extensions tab
- ComfyUI custom nodes: Clone to `ComfyUI/custom_nodes/` directory

### Memory Optimization
For systems with limited GPU memory, add these arguments:
- Automatic1111: `--medvram`, `--lowvram`, `--opt-split-attention`
- ComfyUI: `--lowvram`, `--cpu` 