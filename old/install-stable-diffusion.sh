#!/bin/bash

echo "========================================="
echo "🎨 Stable Diffusion Native Setup Script"
echo "========================================="
echo ""

# Script directory detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$HOME/workspaces/ai/stable-diffusion"

echo "📁 Setting up workspace directory structure..."
mkdir -p "$WORKSPACE_DIR"
mkdir -p "$WORKSPACE_DIR/models"
mkdir -p "$WORKSPACE_DIR/models/Stable-diffusion"
mkdir -p "$WORKSPACE_DIR/models/VAE"
mkdir -p "$WORKSPACE_DIR/models/Lora" 
mkdir -p "$WORKSPACE_DIR/models/ControlNet"
mkdir -p "$WORKSPACE_DIR/outputs"

echo "✅ Directory structure created!"
echo ""

# Change to workspace directory
cd "$WORKSPACE_DIR"

echo "========================================="
echo "🔧 Installing System Dependencies"
echo "========================================="
echo ""

echo "📦 Installing required system packages..."
# Install Python, git, and other dependencies
sudo pacman -S --needed python python-pip python-virtualenv git wget

echo "🔧 Installing build dependencies..."
# Install build tools needed for compiling Python packages
sudo pacman -S --needed base-devel cmake pkg-config

echo "📦 Installing sentencepiece system library..."
# Install sentencepiece from AUR (required for Python sentencepiece to build)
yay -S --needed --noconfirm sentencepiece

echo "🐍 Installing Python 3.10 for Automatic1111..."
# Install Python 3.10 from AUR (required for Automatic1111 compatibility)
yay -S --needed --noconfirm python310

echo "🎮 Installing NVIDIA CUDA toolkit for GPU acceleration..."
sudo pacman -S --needed cuda cudnn

echo "✅ System dependencies installed!"
echo ""

echo "========================================="
echo "🤖 Setting up Automatic1111 WebUI"
echo "========================================="
echo ""

if [ ! -d "automatic1111" ]; then
    echo "📥 Cloning Automatic1111 WebUI repository..."
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git automatic1111
else
    echo "📂 Automatic1111 already exists, updating..."
    cd automatic1111
    git pull
    cd ..
fi

echo "🐍 Creating Python virtual environment for Automatic1111..."
cd automatic1111
if [ ! -d "venv" ]; then
    # Use Python 3.10 for Automatic1111 compatibility
    python3.10 -m venv venv
fi

echo "📦 Installing Automatic1111 dependencies..."
source venv/bin/activate
pip install --upgrade pip
# The webui.sh script will handle most dependencies automatically
deactivate

cd ..
echo "✅ Automatic1111 setup completed!"
echo ""

echo "========================================="
echo "🎨 Setting up ComfyUI"
echo "========================================="
echo ""

if [ ! -d "ComfyUI" ]; then
    echo "📥 Cloning ComfyUI repository..."
    git clone https://github.com/comfyanonymous/ComfyUI.git
else
    echo "📂 ComfyUI already exists, updating..."
    cd ComfyUI
    git pull
    cd ..
fi

echo "🐍 Creating Python virtual environment for ComfyUI..."
cd ComfyUI
if [ ! -d "venv" ]; then
    python -m venv venv
fi

echo "📦 Installing ComfyUI dependencies..."
source venv/bin/activate
pip install --upgrade pip

echo "🔧 Installing PyTorch with CUDA support..."
# Install PyTorch and torchvision with CUDA support first (needed for Python 3.13 + CUDA)
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121

echo "📦 Installing essential compatibility libraries..."
# Install common compatibility libraries that may be missing
pip install six

echo "📦 Installing all ComfyUI requirements..."
# Install all requirements from requirements.txt (sentencepiece should now build successfully)
pip install -r requirements.txt

echo "🔧 Verifying PyTorch installation..."
python -c "import torch; print('PyTorch version:', torch.__version__); print('CUDA available:', torch.cuda.is_available())" || echo "⚠️  PyTorch verification failed"
deactivate

cd ..
echo "✅ ComfyUI setup completed!"
echo ""

echo "========================================="
echo "🔗 Setting up shared models"
echo "========================================="
echo ""

echo "🔄 Creating symlinks for shared models..."

# Create symlinks for Automatic1111
if [ -d "automatic1111/models" ]; then
    echo "Setting up Automatic1111 model symlinks..."
    
    # Remove existing directories and create symlinks
    rm -rf automatic1111/models/Stable-diffusion
    rm -rf automatic1111/models/VAE  
    rm -rf automatic1111/models/Lora
    rm -rf automatic1111/models/ControlNet
    
    ln -sf "../../models/Stable-diffusion" automatic1111/models/Stable-diffusion
    ln -sf "../../models/VAE" automatic1111/models/VAE
    ln -sf "../../models/Lora" automatic1111/models/Lora
    ln -sf "../../models/ControlNet" automatic1111/models/ControlNet
    
    echo "   ✅ Automatic1111 model symlinks created"
fi

# Create symlinks for ComfyUI
if [ -d "ComfyUI/models" ]; then
    echo "Setting up ComfyUI model symlinks..."
    
    # Remove existing directories and create symlinks  
    rm -rf ComfyUI/models/checkpoints
    rm -rf ComfyUI/models/vae
    rm -rf ComfyUI/models/loras
    rm -rf ComfyUI/models/controlnet
    
    ln -sf "../../models/Stable-diffusion" ComfyUI/models/checkpoints
    ln -sf "../../models/VAE" ComfyUI/models/vae
    ln -sf "../../models/Lora" ComfyUI/models/loras
    ln -sf "../../models/ControlNet" ComfyUI/models/controlnet
    
    echo "   ✅ ComfyUI model symlinks created"
fi

echo "✅ Shared models setup completed!"
echo ""

echo "========================================="
echo "📋 Copying Scripts and Documentation"
echo "========================================="
echo ""

# Script directory detection for copying files
SOURCE_DIR="$SCRIPT_DIR/stable-diffusion"

echo "📂 Copying script files from source directory..."

# Copy startup scripts
if [ -f "$SOURCE_DIR/start-automatic1111.sh" ]; then
    cp "$SOURCE_DIR/start-automatic1111.sh" "$WORKSPACE_DIR/"
    chmod +x "$WORKSPACE_DIR/start-automatic1111.sh"
    echo "   ✅ start-automatic1111.sh copied and made executable"
else
    echo "   ❌ start-automatic1111.sh not found in source"
fi

if [ -f "$SOURCE_DIR/start-comfyui.sh" ]; then
    cp "$SOURCE_DIR/start-comfyui.sh" "$WORKSPACE_DIR/"
    chmod +x "$WORKSPACE_DIR/start-comfyui.sh"
    echo "   ✅ start-comfyui.sh copied and made executable"
else
    echo "   ❌ start-comfyui.sh not found in source"
fi

# Copy management script
if [ -f "$SOURCE_DIR/manage-stable-diffusion.sh" ]; then
    cp "$SOURCE_DIR/manage-stable-diffusion.sh" "$WORKSPACE_DIR/"
    chmod +x "$WORKSPACE_DIR/manage-stable-diffusion.sh"
    echo "   ✅ manage-stable-diffusion.sh copied and made executable"
else
    echo "   ❌ manage-stable-diffusion.sh not found in source"
fi

# Copy README
if [ -f "$SOURCE_DIR/README.md" ]; then
    cp "$SOURCE_DIR/README.md" "$WORKSPACE_DIR/"
    echo "   ✅ README.md copied"
else
    echo "   ❌ README.md not found in source"
fi

# Copy Python scripts directory
if [ -d "$SOURCE_DIR/python_scripts" ]; then
    cp -r "$SOURCE_DIR/python_scripts" "$WORKSPACE_DIR/"
    # Make scripts executable
    chmod +x "$WORKSPACE_DIR/python_scripts/download_lora.sh"
    chmod +x "$WORKSPACE_DIR/python_scripts/civitai_lora_downloader.py"
    echo "   ✅ python_scripts directory copied and made executable"
else
    echo "   ❌ python_scripts directory not found in source"
fi

echo "✅ Scripts and documentation copied!"
echo ""

echo "========================================="
echo "🎉 Native Stable Diffusion setup completed!"
echo "========================================="
echo ""
echo "📁 Installation directory: $WORKSPACE_DIR"
echo ""
echo "🚀 Quick start commands:"
echo "   cd $WORKSPACE_DIR"
echo "   ./start-automatic1111.sh    # Start Automatic1111 WebUI"
echo "   ./start-comfyui.sh          # Start ComfyUI"
echo ""
echo "   # Or use the management script:"
echo "   ./manage-stable-diffusion.sh start auto    # Start Automatic1111"
echo "   ./manage-stable-diffusion.sh start comfy   # Start ComfyUI"
echo ""
echo "🌐 Web interfaces:"
echo "   Automatic1111: http://localhost:7860"
echo "   ComfyUI:       http://localhost:8188"
echo ""
echo "📂 Models directory: $WORKSPACE_DIR/models"
echo "   - Place .safetensors/.ckpt files in models/Stable-diffusion/"
echo "   - Place VAE files in models/VAE/"
echo "   - Place LoRA files in models/Lora/"
echo "   - Place ControlNet files in models/ControlNet/"
echo ""
echo "🔧 Python tools:"
echo "   ./python_scripts/download_lora.sh <civitai_url>  # Download LoRA from Civitai"
echo ""
echo "💡 Next steps:"
echo "   1. Download some models (e.g., from Hugging Face or Civitai)"
echo "   2. Place them in the appropriate model directories"
echo "   3. Start your preferred service"
echo "   4. Open the web interface in your browser"
echo ""
echo "🔄 To update: ./manage-stable-diffusion.sh update"
echo "" 