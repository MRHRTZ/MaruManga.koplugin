#!/bin/sh
set -eu
work=$(mktemp -d); pid=''
cleanup() { if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || :; fi; rm -rf "$work"; }
trap cleanup EXIT INT TERM
mkdir "$work/ca"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -keyout "$work/key.pem" -out "$work/ca/test.pem" -subj '/CN=api.mangadex.org' -addext 'subjectAltName=DNS:api.mangadex.org,DNS:node.mangadex.network,DNS:api.mangadex.network' >/dev/null 2>&1
openssl rehash "$work/ca"
python3 tests/mangadex_https_fixture.py 18444 "$work/ca/test.pem" "$work/key.pem" >"$work/server.log" 2>&1 &
pid=$!
sleep 1
TEST_CA_DIR="$work/ca" TEST_PORT=18444 "${LUAJIT:-luajit}" tests/integration_mangadex_loopback.lua
wait "$pid"; pid=''
if [ -n "${KOREADER_BASE:-}" ] && [ -n "${LIBARCHIVE_PATH:-}" ]; then
    TEST_FULL=1 python3 tests/mangadex_https_fixture.py 18445 "$work/ca/test.pem" "$work/key.pem" >"$work/server.log" 2>&1 &
    pid=$!
    sleep 1
    TEST_FULL=1 KOREADER_BASE="$KOREADER_BASE" LIBARCHIVE_PATH="$LIBARCHIVE_PATH" TEST_CA_DIR="$work/ca" TEST_PORT=18445 "${LUAJIT:-luajit}" tests/integration_mangadex_loopback.lua
    wait "$pid"; pid=''
fi
