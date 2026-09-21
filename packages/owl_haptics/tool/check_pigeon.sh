#!/usr/bin/env bash

set -euo pipefail

package_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
check_dir="$(mktemp -d "${TMPDIR:-/tmp}/owl-haptics-pigeon.XXXXXX")"

cleanup() {
  rm -rf -- "$check_dir"
}
trap cleanup EXIT

cd "$package_dir"

dart run pigeon \
  --input pigeons/messages.dart \
  --package_name owl_haptics \
  --dart_out "$check_dir/messages.g.dart" \
  --kotlin_out "$check_dir/Messages.g.kt" \
  --kotlin_package com.owlllwo.owl_haptics \
  --swift_out "$check_dir/Messages.g.swift"

dart format "$check_dir/messages.g.dart" >/dev/null

cmp "$check_dir/messages.g.dart" lib/src/messages.g.dart
cmp "$check_dir/Messages.g.kt" android/src/main/kotlin/com/owlllwo/owl_haptics/Messages.g.kt
cmp "$check_dir/Messages.g.swift" ios/owl_haptics/Sources/owl_haptics/Messages.g.swift
