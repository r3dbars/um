#!/bin/bash
# One-command build & run for Um
set -e

echo "Building Um..."
swift build 2>&1

echo "Launching Um..."
.build/debug/Um &
echo "Um is running in your menu bar!"
