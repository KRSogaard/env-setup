#!/usr/bin/env python3
"""
Civitai LoRA Downloader Script

Downloads LoRA models from Civitai URLs, organizes them in subfolders by type,
downloads thumbnails, and creates metadata files.

Usage: python civitai_lora_downloader.py <civitai_url>
"""

import os
import sys
import json
import requests
import re
import shutil
from pathlib import Path
from urllib.parse import urlparse, parse_qs
from bs4 import BeautifulSoup
import argparse
from typing import Dict, List, Optional
import time

class CivitaiLoRADownloader:
    def __init__(self, base_path: str = "~/workspaces/ai/stable-diffusion/models/Lora"):
        self.base_path = Path(base_path).expanduser().resolve()
        self.base_path.mkdir(parents=True, exist_ok=True)
        self.downloads_path = Path("~/workspaces/ai/stable-diffusion/downloads/lora").expanduser().resolve()
        self.downloads_path.mkdir(parents=True, exist_ok=True)
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        })
        
    def parse_civitai_url(self, url: str) -> Dict[str, str]:
        """Parse Civitai URL to extract model ID and version ID"""
        # Remove @ prefix if present
        url = url.lstrip('@')
        
        # Extract model ID from URL
        model_match = re.search(r'/models/(\d+)', url)
        if not model_match:
            raise ValueError("Could not extract model ID from URL")
        
        model_id = model_match.group(1)
        
        # Extract version ID from URL parameters
        parsed_url = urlparse(url)
        query_params = parse_qs(parsed_url.query)
        version_id = query_params.get('modelVersionId', [None])[0]
        
        return {
            'model_id': model_id,
            'version_id': version_id,
            'url': url
        }
    
    def get_model_info(self, model_id: str, version_id: Optional[str] = None) -> Dict:
        """Fetch model information from Civitai API"""
        api_url = f"https://civitai.com/api/v1/models/{model_id}"
        
        try:
            response = self.session.get(api_url)
            response.raise_for_status()
            model_data = response.json()
            
            # If version_id is specified, find that specific version
            if version_id:
                for version in model_data.get('modelVersions', []):
                    if str(version['id']) == version_id:
                        model_data['selectedVersion'] = version
                        break
                else:
                    print(f"Warning: Version ID {version_id} not found, using latest version")
                    model_data['selectedVersion'] = model_data['modelVersions'][0] if model_data.get('modelVersions') else None
            else:
                # Use the first (latest) version
                model_data['selectedVersion'] = model_data['modelVersions'][0] if model_data.get('modelVersions') else None
            
            return model_data
            
        except requests.RequestException as e:
            print(f"Error fetching model info: {e}")
            # Fallback to web scraping
            return self.scrape_model_info(model_id, version_id)
    
    def scrape_model_info(self, model_id: str, version_id: Optional[str] = None) -> Dict:
        """Fallback web scraping method to get model information"""
        url = f"https://civitai.com/models/{model_id}"
        if version_id:
            url += f"?modelVersionId={version_id}"
            
        try:
            response = self.session.get(url)
            response.raise_for_status()
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Extract basic information
            title_elem = soup.find('h1')
            title = title_elem.text.strip() if title_elem else f"Model_{model_id}"
            
            # Try to find download links
            download_links = []
            for link in soup.find_all('a', href=True):
                if 'download' in link['href'].lower():
                    download_links.append(link['href'])
            
            # Extract tags/types
            tags = []
            for tag_elem in soup.find_all(class_=re.compile(r'tag|badge')):
                if tag_elem.text.strip():
                    tags.append(tag_elem.text.strip())
            
            return {
                'name': title,
                'id': int(model_id),
                'type': 'LORA',
                'tags': tags,
                'selectedVersion': {
                    'id': int(version_id) if version_id else None,
                    'name': title,
                    'downloadUrl': download_links[0] if download_links else None,
                    'files': []
                }
            }
            
        except Exception as e:
            print(f"Error scraping model info: {e}")
            return None
    
    def sanitize_filename(self, filename: str) -> str:
        """Sanitize filename for filesystem compatibility"""
        # Remove or replace invalid characters
        filename = re.sub(r'[<>:"/\\|?*]', '_', filename)
        filename = re.sub(r'\s+', '_', filename)
        return filename.strip('._')
    
    def determine_subfolder(self, model_data: Dict) -> str:
        """Determine subfolder based on model type and tags"""
        if not model_data:
            return "general"
            
        tags = model_data.get('tags', [])
        model_type = model_data.get('type', '').lower()
        
        # Convert tags to lowercase for comparison
        tags_lower = [tag.lower() for tag in tags]
        
        # Categorize based on tags
        if any(tag in tags_lower for tag in ['character', 'person', 'celebrity']):
            return "character"
        elif any(tag in tags_lower for tag in ['style', 'art', 'artistic']):
            return "style"
        elif any(tag in tags_lower for tag in ['concept', 'abstract']):
            return "concept"
        elif any(tag in tags_lower for tag in ['clothing', 'outfit', 'fashion']):
            return "clothing"
        elif any(tag in tags_lower for tag in ['pose', 'action']):
            return "pose"
        elif any(tag in tags_lower for tag in ['background', 'environment', 'scenery']):
            return "background"
        else:
            return "general"
    
    def download_file(self, url: str, filepath: Path, description: str = "file") -> bool:
        """Download a file with progress indication"""
        try:
            print(f"Downloading {description}...")
            response = self.session.get(url, stream=True)
            response.raise_for_status()
            
            total_size = int(response.headers.get('content-length', 0))
            
            with open(filepath, 'wb') as f:
                downloaded = 0
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        if total_size > 0:
                            progress = (downloaded / total_size) * 100
                            print(f"\r{description}: {progress:.1f}% ({downloaded}/{total_size} bytes)", end='')
            
            print(f"\n✓ Downloaded {description} successfully")
            return True
            
        except Exception as e:
            print(f"\n✗ Error downloading {description}: {e}")
            return False
    
    def download_thumbnail(self, model_data: Dict, model_dir: Path, lora_filename: str) -> str:
        """Download single thumbnail image with same name as LoRA file"""
        if not model_data or 'selectedVersion' not in model_data:
            return ""
            
        version = model_data['selectedVersion']
        images = version.get('images', [])
        
        if not images:
            print("No thumbnail found")
            return ""
        
        # Get the first (main) image
        image = images[0]
        image_url = image.get('url')
        if not image_url:
            print("No thumbnail URL found")
            return ""
        
        # Determine file extension from URL
        ext = '.jpg'  # default
        if image_url.lower().endswith('.png'):
            ext = '.png'
        elif image_url.lower().endswith('.webp'):
            ext = '.webp'
        
        # Create thumbnail with same name as LoRA file
        lora_name_without_ext = Path(lora_filename).stem
        thumbnail_path = model_dir / f"{lora_name_without_ext}{ext}"
        
        if self.download_file(image_url, thumbnail_path, "thumbnail"):
            return thumbnail_path.name
        
        return ""
    
    def wait_for_manual_download(self, model_name: str, download_url: str) -> Path:
        """Wait for user to manually download the LoRA file"""
        print(f"\n{'='*60}")
        print("🔐 MANUAL DOWNLOAD REQUIRED")
        print(f"{'='*60}")
        print(f"The LoRA file '{model_name}' requires authentication to download.")
        print(f"Please follow these steps:")
        print(f"")
        print(f"1. Open this URL in your browser:")
        print(f"   {download_url}")
        print(f"")
        print(f"2. Log in to Civitai if prompted")
        print(f"")
        print(f"3. Download the LoRA file (.safetensors)")
        print(f"")
        print(f"4. Place the downloaded file in:")
        print(f"   {self.downloads_path}")
        print(f"")
        print(f"5. Press ENTER once you've downloaded and placed the file...")
        print(f"{'='*60}")
        
        input()  # Wait for user input
        
        # Look for recently downloaded files
        lora_files = list(self.downloads_path.glob("*.safetensors"))
        
        if not lora_files:
            raise FileNotFoundError(f"No .safetensors files found in {self.downloads_path}")
        
        if len(lora_files) == 1:
            return lora_files[0]
        
        # Multiple files found, ask user to choose
        print(f"\nMultiple LoRA files found in downloads folder:")
        for i, file in enumerate(lora_files, 1):
            print(f"{i}. {file.name}")
        
        while True:
            try:
                choice = int(input(f"\nWhich file is the LoRA for '{model_name}'? (1-{len(lora_files)}): ")) - 1
                if 0 <= choice < len(lora_files):
                    return lora_files[choice]
                else:
                    print("Invalid choice. Please try again.")
            except ValueError:
                print("Please enter a valid number.")
    
    def create_metadata(self, model_data: Dict, model_dir: Path, lora_filename: str, thumbnail: str, download_url: str = None) -> None:
        """Create metadata file in Automatic1111 format"""
        if not model_data:
            return
            
        version = model_data.get('selectedVersion', {})
        
        # Get trained words/activation text
        trained_words = version.get('trainedWords', [])
        activation_text = ', '.join(trained_words) if trained_words else ''
        
        # Determine SD version from base model
        base_model = version.get('baseModel', '').lower()
        if 'xl' in base_model or 'sdxl' in base_model:
            sd_version = 'SDXL'
        elif 'sd3' in base_model:
            sd_version = 'SD3'
        elif 'flux' in base_model:
            sd_version = 'FLUX'
        elif 'illustrious' in base_model or 'pony' in base_model:
            sd_version = 'SDXL'
        else:
            sd_version = 'SD1.5'
        
        # Create Automatic1111 compatible metadata
        metadata = {
            'description': model_data.get('description', '') or version.get('description', ''),
            'sd version': sd_version,
            'activation text': activation_text,
            'preferred weight': 1.0,
            'negative text': '',
            'notes': f"Downloaded from Civitai on {time.strftime('%Y-%m-%d %H:%M:%S')}"
        }
        
        # Add additional useful information
        if model_data.get('tags'):
            metadata['tags'] = ', '.join(model_data.get('tags', []))
        
        if version.get('baseModel'):
            metadata['base model'] = version.get('baseModel')
        
        if download_url:
            metadata['download url'] = download_url
            
        if model_data.get('id'):
            metadata['civitai id'] = model_data.get('id')
            
        if version.get('id'):
            metadata['version id'] = version.get('id')
            
        if thumbnail:
            metadata['thumbnail'] = thumbnail
        
        # Create metadata file with same name as LoRA file
        lora_name_without_ext = Path(lora_filename).stem
        metadata_path = model_dir / f"{lora_name_without_ext}.json"
        
        with open(metadata_path, 'w', encoding='utf-8') as f:
            json.dump(metadata, f, indent=4, ensure_ascii=False)
        
        print(f"✓ Created metadata file: {metadata_path}")
        
        # Also create a detailed info file for reference
        detailed_metadata = {
            'civitai_info': {
                'name': model_data.get('name', 'Unknown'),
                'id': model_data.get('id'),
                'type': model_data.get('type', 'LORA'),
                'description': model_data.get('description', ''),
                'tags': model_data.get('tags', []),
                'nsfw': model_data.get('nsfw', False),
                'version': {
                    'id': version.get('id'),
                    'name': version.get('name', ''),
                    'description': version.get('description', ''),
                    'baseModel': version.get('baseModel', ''),
                    'createdAt': version.get('createdAt', ''),
                    'updatedAt': version.get('updatedAt', ''),
                    'trainedWords': version.get('trainedWords', []),
                },
                'files': {
                    'lora': lora_filename,
                    'thumbnail': thumbnail
                },
                'download_info': {
                    'downloaded_at': time.strftime('%Y-%m-%d %H:%M:%S'),
                    'source': 'civitai',
                    'download_url': download_url
                }
            }
        }
        
        info_path = model_dir / f"{lora_name_without_ext}.civitai.json"
        with open(info_path, 'w', encoding='utf-8') as f:
            json.dump(detailed_metadata, f, indent=2, ensure_ascii=False)
    
    def download_lora(self, url: str) -> bool:
        """Main method to download LoRA from Civitai URL"""
        try:
            print(f"Processing URL: {url}")
            
            # Parse URL
            url_info = self.parse_civitai_url(url)
            print(f"Model ID: {url_info['model_id']}, Version ID: {url_info['version_id']}")
            
            # Get model information
            model_data = self.get_model_info(url_info['model_id'], url_info['version_id'])
            if not model_data:
                print("✗ Could not retrieve model information")
                return False
            
            print(f"Found model: {model_data.get('name', 'Unknown')}")
            
            # Determine subfolder
            subfolder = self.determine_subfolder(model_data)
            print(f"Category: {subfolder}")
            
            # Create category directory (no subfolder for individual models)
            model_dir = self.base_path / subfolder
            model_dir.mkdir(parents=True, exist_ok=True)
            
            # Get sanitized model name for filename
            model_name = self.sanitize_filename(model_data.get('name', f"model_{url_info['model_id']}"))
            
            # Find download URL
            version = model_data.get('selectedVersion', {})
            files = version.get('files', [])
            
            download_url = None
            filename = None
            
            # Look for the main LoRA file
            for file_info in files:
                if file_info.get('type') == 'Model' or file_info.get('name', '').endswith('.safetensors'):
                    download_url = file_info.get('downloadUrl')
                    filename = file_info.get('name')
                    break
            
            if not download_url and version.get('downloadUrl'):
                download_url = version['downloadUrl']
                filename = f"{model_name}.safetensors"
            
            if not download_url:
                print("✗ Could not find download URL")
                return False
            
            # Get the LoRA file via manual download
            try:
                downloaded_file = self.wait_for_manual_download(model_name, download_url)
                
                # Create target filename 
                target_filename = filename or f"{model_name}.safetensors"
                lora_path = model_dir / target_filename
                
                # Copy the downloaded file to the correct location
                print(f"Copying LoRA file to: {lora_path}")
                shutil.copy2(downloaded_file, lora_path)
                
                # Clean up the downloaded file
                downloaded_file.unlink()
                print("✓ LoRA file copied successfully")
                
            except Exception as e:
                print(f"✗ Error handling manual download: {e}")
                return False
            
            # Download thumbnail
            print("\nDownloading thumbnail...")
            thumbnail = self.download_thumbnail(model_data, model_dir, lora_path.name)
            
            # Create metadata
            print("\nCreating metadata...")
            self.create_metadata(model_data, model_dir, lora_path.name, thumbnail, download_url)
            
            print(f"\n✅ Successfully downloaded LoRA to: {model_dir}")
            return True
            
        except Exception as e:
            print(f"✗ Error downloading LoRA: {e}")
            return False

def main():
    parser = argparse.ArgumentParser(description='Download LoRA models from Civitai')
    parser.add_argument('url', help='Civitai model URL (with or without @ prefix)')
    parser.add_argument('--base-path', default='~/workspaces/ai/stable-diffusion/models/Lora',
                      help='Base path for LoRA models (default: ~/workspaces/ai/stable-diffusion/models/Lora)')
    
    args = parser.parse_args()
    
    downloader = CivitaiLoRADownloader(args.base_path)
    success = downloader.download_lora(args.url)
    
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main() 