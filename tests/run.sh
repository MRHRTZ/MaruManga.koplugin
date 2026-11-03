#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
for test_file in tests/test_*.lua; do
    "${LUAJIT:-luajit}" "$test_file"
done
