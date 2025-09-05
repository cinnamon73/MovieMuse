#!/bin/sh
set -euo pipefail

# Xcode Cloud default hook path
echo "[Xcode Cloud] ci_pre_xcodebuild.sh: delegating to pre_xcodebuild.sh"
DIR=$(cd "$(dirname "$0")" && pwd)
"$DIR/pre_xcodebuild.sh"


