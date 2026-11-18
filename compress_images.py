import os
from PIL import Image

def convert_to_jpeg(input_path, output_path, quality=70):
    try:
        with Image.open(input_path) as img:
            if img.mode == 'RGBA':
                img = img.convert('RGB')
            img.save(output_path, 'JPEG', quality=quality, optimize=True)
            original_size = os.path.getsize(input_path)
            compressed_size = os.path.getsize(output_path)
            print(f"Converted {os.path.basename(input_path)}: {original_size/1024/1024:.2f}MB -> {compressed_size/1024/1024:.2f}MB")
            return output_path
    except Exception as e:
        print(f"Failed to convert {input_path}: {e}")
        return None

def main():
    source_dir = r'D:\Trae CN\program\game'
    target_dir = r'D:\Trae CN\program\game\guess_character_game_mobile_new\assets'
    
    images = {
        'IMG_20260722_122923.png': 'bg_music.jpeg',
        'IMG_20260722_123107.png': 'bg_game.jpeg',
        'IMG_20260722_123134.png': 'miku.jpeg',
    }
    
    for src_name, dest_name in images.items():
        src_path = os.path.join(source_dir, src_name)
        dest_path = os.path.join(target_dir, dest_name)
        
        if os.path.exists(src_path):
            convert_to_jpeg(src_path, dest_path, quality=80)
        else:
            print(f"File not found: {src_path}")
    
    print("\nConverted files:")
    for img in images.values():
        path = os.path.join(target_dir, img)
        if os.path.exists(path):
            size = os.path.getsize(path)
            print(f"{img}: {size/1024/1024:.2f}MB")

if __name__ == '__main__':
    main()
