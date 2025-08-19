#!/usr/bin/env python3
"""
Create placeholder PNG icons for testing Flutter app icon generation.
This script creates simple colored PNG files as placeholders.
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_placeholder_icon(size, filename, text="MP"):
    """Create a placeholder icon with the given size and text."""
    # Create image with purple background
    img = Image.new('RGBA', (size, size), (103, 58, 183, 255))
    draw = ImageDraw.Draw(img)
    
    # Try to use a system font, fallback to default
    try:
        font_size = size // 4
        font = ImageFont.truetype("arial.ttf", font_size)
    except:
        try:
            font = ImageFont.load_default()
        except:
            font = None
    
    # Calculate text position to center it
    if font:
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
    else:
        text_width = len(text) * (size // 8)
        text_height = size // 8
    
    x = (size - text_width) // 2
    y = (size - text_height) // 2
    
    # Draw white text
    draw.text((x, y), text, fill=(255, 255, 255, 255), font=font)
    
    # Draw a simple movie-like border
    border_width = size // 20
    draw.rectangle([border_width, border_width, size-border_width, size-border_width], 
                  outline=(255, 215, 0, 255), width=border_width//2)
    
    # Save the image
    img.save(filename, 'PNG')
    print(f"Created {filename} ({size}x{size})")

def main():
    # Create assets/icons directory if it doesn't exist
    os.makedirs('assets/icons', exist_ok=True)
    
    # Create main app icon (1024x1024)
    create_placeholder_icon(1024, 'assets/icons/app_icon.png', 'MP')
    
    # Create splash icon (512x512)
    create_placeholder_icon(512, 'assets/icons/splash_icon.png', 'MP')
    
    print("\nPlaceholder icons created successfully!")
    print("You can now run:")
    print("  flutter pub run flutter_launcher_icons:main")
    print("  flutter pub run flutter_native_splash:create")
    print("\nReplace these placeholder files with the converted SVG files later.")

if __name__ == "__main__":
    main() 