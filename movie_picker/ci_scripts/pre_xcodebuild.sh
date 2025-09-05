#!/bin/sh
set -euo pipefail

echo "[Xcode Cloud] pre_xcodebuild: CocoaPods setup"
if command -v pod >/dev/null 2>&1; then
  echo "[Xcode Cloud] CocoaPods version: $(pod --version)"
else
  echo "[Xcode Cloud] Installing CocoaPods"
  gem install cocoapods -N
fi

echo "[Xcode Cloud] pod install (deployment) in ios/"
cd ios
pod install --deployment
cd - >/dev/null

echo "[Xcode Cloud] pre_xcodebuild complete"


