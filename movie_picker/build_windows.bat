@echo off
echo Cleaning Flutter project...
flutter clean

echo Getting dependencies...
flutter pub get

echo Building Windows app...
flutter build windows --debug --no-tree-shake-icons

echo Build complete! Running app...
flutter run --debug -d windows

pause 