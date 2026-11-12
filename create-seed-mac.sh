#!/bin/bash
set -e

cd "$(dirname "$0")"

mkisofs \
  -output seed.iso \
  -volid cidata \
  -joliet \
  -rock \
  user-data meta-data

echo "ISO generated successfully!"