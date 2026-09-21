#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
dart run pigeon --input pigeons/gromore_api.dart

