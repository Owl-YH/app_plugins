#!/usr/bin/env bash
set -euo pipefail

package_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$package_dir"

flutter pub get
dart format --output=none --set-exit-if-changed lib test example/lib example/test
flutter analyze --no-pub
flutter test --no-pub \
  test/simulation_test.dart \
  test/rendering_test.dart \
  test/optimization_test.dart \
  test/paper_shapes_test.dart \
  test/paper_aerodynamics_test.dart \
  test/paper_bending_test.dart \
  test/fade_test.dart \
  test/host_test.dart \
  test/overlay_test.dart

cd example
flutter pub get
flutter test --no-pub test/example_test.dart
