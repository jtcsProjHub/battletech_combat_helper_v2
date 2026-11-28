#!/usr/bin/env bash
# Builds the phone web client (client/) into client/build/web, where the
# desktop app finds and serves it during play.
#
# --no-web-resources-cdn: phones on the hotspot have no internet, so
# CanvasKit must be served by the laptop instead of Google's CDN.
set -euo pipefail
cd "$(dirname "$0")/../client"
flutter pub get
flutter build web --release --no-web-resources-cdn --base-href / "$@"
echo "Built $(pwd)/build/web"
