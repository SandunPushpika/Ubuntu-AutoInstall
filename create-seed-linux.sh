#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v cloud-localds >/dev/null 2>&1; then
  echo "Error: cloud-localds is not installed."
  exit 1
fi

cloud-localds seed.iso user-data meta-data

echo "Created seed.iso successfully."