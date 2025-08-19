# App Icons Setup

## Current Status
- ✅ SVG app icon created (`app_icon.svg`)
- ⏳ PNG conversion needed
- ⏳ Splash screen icon needed

## Required Actions

### 1. Convert SVG to PNG
The `app_icon.svg` file needs to be converted to PNG format for Flutter to use.

**Recommended Online Converters:**
- https://svgtopng.com/ (Free, up to 20 files)
- https://cloudconvert.com/svg-to-png (Free tier available)
- https://image.online-convert.com/convert/svg-to-png

**Conversion Settings:**
- **Size**: 1024x1024 pixels (high resolution)
- **Format**: PNG
- **Quality**: Maximum/100%
- **Background**: Transparent (if supported)

**Steps:**
1. Open one of the online converters above
2. Upload the `app_icon.svg` file
3. Set size to 1024x1024 pixels
4. Download as `app_icon.png`
5. Save the downloaded file as `assets/icons/app_icon.png`

### 2. Create Splash Screen Icon
Create a simpler version for splash screen:
1. Use the same online converter
2. Convert `app_icon.svg` to PNG
3. Set size to 512x512 pixels (smaller for splash)
4. Save as `assets/icons/splash_icon.png`

### 3. Generate Icons
After both PNG files are ready:

```bash
# Get dependencies
flutter pub get

# Generate app icons for all platforms
flutter pub run flutter_launcher_icons:main

# Generate splash screens
flutter pub run flutter_native_splash:create
```

## Icon Design Features
- **Background**: Purple gradient (#673ab7 to #3f51b5)
- **Main Element**: Film strip with movie frame
- **Center**: Play button with app branding
- **Details**: Star ratings, swipe indicators
- **Text**: "Movie Picker" app name
- **Style**: Professional, modern, recognizable

## Platform Support
The configuration will generate icons for:
- ✅ Android (all densities: mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)
- ✅ iOS (all required sizes)
- ✅ Windows (48px default)
- ✅ macOS (all required sizes)
- ✅ Web (favicon and PWA icons)

## File Structure After Setup
```
assets/icons/
├── app_icon.svg          # Source vector file
├── app_icon.png          # 1024x1024 main icon
├── splash_icon.png       # 512x512 splash icon
└── README.md            # This file
```

## Next Steps
1. Convert SVG files to PNG using online tools
2. Run the generation commands
3. Test the app on different platforms
4. Verify icons appear correctly in all contexts 