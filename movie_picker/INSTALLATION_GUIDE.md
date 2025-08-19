# Movie Picker - Installation Guide

## ✅ **What Was Fixed**

1. **Added Internet Permission** - Android manifest now includes required network permissions
2. **Updated NDK Version** - Fixed to use NDK 27.0.12077973 for compatibility 
3. **Cleaned Build Cache** - Removed corrupted Kotlin compilation cache
4. **Added Adult Content Filter** - Proper privacy settings integration

## 🚀 **Quick Installation**

### Method 1: Use the Install Script
```bash
# Run the automated installation script
./install_debug.bat
```

### Method 2: Manual Installation
```bash
# 1. Connect your Android device with USB debugging enabled
adb devices

# 2. Uninstall existing app (if any)
adb uninstall com.example.movie_picker

# 3. Clean and build
flutter clean
flutter pub get
flutter build apk --debug

# 4. Install the app
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### Method 3: Direct Flutter Run
```bash
# Make sure device is connected
flutter devices

# Run directly on device
flutter run
```

## 🔧 **Troubleshooting**

### Problem: "No devices found"
**Solution:**
1. Enable Developer Options on Android device
2. Enable USB Debugging
3. Reconnect device and authorize computer
4. Run `adb devices` to verify

### Problem: "Installation failed"
**Solution:**
```bash
# Try these steps in order:
adb uninstall com.example.movie_picker
flutter clean
flutter pub get
flutter run --verbose
```

### Problem: "NDK version mismatch"
**Solution:** Already fixed! The build.gradle.kts now uses NDK 27.0.12077973

### Problem: "Kotlin compilation errors"
**Solution:**
```bash
# Clear caches and rebuild
flutter clean
Remove-Item -Recurse -Force build/ -ErrorAction SilentlyContinue
flutter pub get
```

### Problem: "App shows no movies"
**Solution:** Fixed! Added INTERNET permission to AndroidManifest.xml

## 📱 **Device Setup**

### Android Device Requirements:
- Android 5.0+ (API level 21+)
- USB Debugging enabled
- Unknown sources allowed (for debug installs)

### Enable USB Debugging:
1. Go to Settings → About Phone
2. Tap "Build Number" 7 times
3. Go to Settings → Developer Options
4. Enable "USB Debugging"

## 🎬 **First Launch**

After successful installation:
1. Open the Movie Picker app
2. Accept privacy policy
3. Complete onboarding
4. Movies should load automatically
5. If no movies appear, check internet connection

## 📋 **What's New**

### Fixed Issues:
- ✅ Android internet permissions added
- ✅ NDK version compatibility resolved
- ✅ Build cache corruption fixed
- ✅ Movie loading on Android devices working
- ✅ Firebase Analytics logging reduced

### Features Working:
- 🎬 Movie discovery and filtering
- 📱 Swipe gestures for like/dislike
- 🔖 Bookmarking system
- 👤 User profiles and preferences
- 🔍 Search functionality
- 📊 Analytics (minimal logging)

## 🆘 **Need Help?**

If you encounter issues:
1. Try the troubleshooting steps above
2. Check that USB debugging is enabled
3. Ensure device is authorized for debugging
4. Try running `flutter doctor` to check setup

## 🎯 **Success Indicators**

The app is working correctly when:
- ✅ App installs without errors
- ✅ Movies load on home screen
- ✅ Swiping works smoothly
- ✅ Filters apply correctly
- ✅ No "no movies" message appears 