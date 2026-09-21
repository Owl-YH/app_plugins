#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
check_dir="$(mktemp -d)"
dart_file="lib/src/pigeon/gromore_api.g.dart"
kotlin_file="android/src/main/kotlin/com/owlllwo/plugins/gromore/GromoreApi.g.kt"
swift_file="ios/owl_ads_gromore/Sources/owl_ads_gromore/GromoreApi.g.swift"

cp "$dart_file" "$check_dir/dart.original"
cp "$kotlin_file" "$check_dir/kotlin.original"
cp "$swift_file" "$check_dir/swift.original"

restore_generated_files() {
  cp "$check_dir/dart.original" "$dart_file"
  cp "$check_dir/kotlin.original" "$kotlin_file"
  cp "$check_dir/swift.original" "$swift_file"
  rm -rf "$check_dir"
}
trap restore_generated_files EXIT

dart run pigeon --input pigeons/gromore_api.dart

diff -u "$check_dir/dart.original" "$dart_file"
diff -u "$check_dir/kotlin.original" "$kotlin_file"
diff -u "$check_dir/swift.original" "$swift_file"
