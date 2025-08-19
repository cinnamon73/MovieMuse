@echo off
echo Movie Picker - Debug Installation Script
echo =========================================

echo.
echo Step 1: Checking connected devices...
adb devices

echo.
echo Step 2: Uninstalling existing app (if any)...
adb uninstall com.example.movie_picker

echo.
echo Step 3: Cleaning Flutter project...
flutter clean

echo.
echo Step 4: Getting dependencies...
flutter pub get

echo.
echo Step 5: Building and installing debug APK...
flutter install

echo.
echo Installation complete! Check your device.
pause 