#!/bin/sh
set -euo pipefail

echo "[CI] Pre Xcode build: ensuring CocoaPods are up to date"
env | sort

if command -v pod >/dev/null 2>&1; then
  echo "[CI] CocoaPods version: $(pod --version)"
else
  echo "[CI] Installing CocoaPods gem"
  gem install cocoapods -N
fi

echo "[CI] Running pod repo update"
pod repo update

echo "[CI] Installing pods"
cd ios
pod install
cd - >/dev/null

echo "[CI] Pre Xcode build complete"


