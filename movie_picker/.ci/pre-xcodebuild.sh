#!/bin/sh

# Pre-build script for Xcode Cloud
# This ensures Flutter and CocoaPods are properly set up

set -e

echo "🚀 Setting up Flutter environment for Xcode Cloud..."

# Ensure we're in the right directory
cd $CI_WORKSPACE

# Flutter setup
echo "📱 Setting up Flutter..."
flutter clean
flutter pub get

# CocoaPods setup
echo "🔧 Setting up CocoaPods..."
cd ios
pod install --repo-update

echo "✅ Pre-build setup complete!"
