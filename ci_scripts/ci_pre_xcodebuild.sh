#!/bin/sh
set -euo pipefail

echo "[Xcode Cloud] root ci_pre_xcodebuild.sh"

if command -v pod >/dev/null 2>&1; then
  echo "[Xcode Cloud] CocoaPods: $(pod --version)"
else
  echo "[Xcode Cloud] Installing CocoaPods"
  gem install cocoapods -N
fi

echo "[Xcode Cloud] cd movie_picker/ios && pod install --deployment"
cd movie_picker/ios
pod install --deployment
cd - >/dev/null

echo "[Xcode Cloud] done"


