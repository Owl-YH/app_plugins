#!/usr/bin/env bash
set -euo pipefail

package_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$package_dir"

flutter pub get
bash tool/check_pigeon.sh
dart format --output=none --set-exit-if-changed lib test example pigeons
flutter analyze --no-pub
flutter test --no-pub
