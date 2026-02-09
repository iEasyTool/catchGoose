#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
OUTPUT_DIR="${PROJECT_ROOT}/output"
APK_SOURCE="${PROJECT_ROOT}/build/app/outputs/flutter-apk/app-release.apk"
APK_TARGET="${OUTPUT_DIR}/catchgoose-release.apk"

cd "${PROJECT_ROOT}"

mkdir -p "${OUTPUT_DIR}"
flutter build apk --release

if [[ ! -f "${APK_SOURCE}" ]]; then
  echo "Build succeeded but APK not found: ${APK_SOURCE}" >&2
  exit 1
fi

cp -f "${APK_SOURCE}" "${APK_TARGET}"
echo "APK ready: ${APK_TARGET}"
