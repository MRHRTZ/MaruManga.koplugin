#!/bin/sh
set -eu
work=$(mktemp -d)
pid=''
cleanup() { if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || :; fi; rm -rf "$work"; }
trap cleanup EXIT INT TERM
mkdir "$work/ca"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -keyout "$work/key.pem" -out "$work/ca/test.pem" -subj '/CN=api.mangadex.org' -addext 'subjectAltName=DNS:api.mangadex.org' >/dev/null 2>&1
openssl rehash "$work/ca"
openssl s_server -quiet -www -accept 127.0.0.1:18443 -cert "$work/ca/test.pem" -key "$work/key.pem" >"$work/server.log" 2>&1 &
pid=$!
sleep 1
TEST_CA_DIR="$work/ca" TEST_PORT=18443 "${LUAJIT:-luajit}" tests/integration_tls_loopback.lua
kill "$pid"; wait "$pid" 2>/dev/null || :; pid=''
python3 tests/tls_post_fixture.py 18443 "$work/ca/test.pem" "$work/key.pem" >"$work/server.log" 2>&1 &
pid=$!
sleep 1
TEST_POST=1 TEST_CA_DIR="$work/ca" TEST_PORT=18443 "${LUAJIT:-luajit}" tests/integration_tls_loopback.lua
wait "$pid"; pid=''
openssl s_server -quiet -www -accept 127.0.0.1:18443 -cert "$work/ca/test.pem" -key "$work/key.pem" >"$work/server.log" 2>&1 &
pid=$!
sleep 1
mkdir "$work/empty-ca"
EXPECT_UNTRUSTED=1 TEST_CA_DIR="$work/empty-ca" TEST_PORT=18443 "${LUAJIT:-luajit}" tests/integration_tls_loopback.lua
kill "$pid"; wait "$pid" 2>/dev/null || :; pid=''
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -keyout "$work/badkey.pem" -out "$work/ca/bad.pem" -subj '/CN=wrong.example' -addext 'subjectAltName=DNS:wrong.example' >/dev/null 2>&1
openssl rehash "$work/ca"
openssl s_server -quiet -www -accept 127.0.0.1:18443 -cert "$work/ca/bad.pem" -key "$work/badkey.pem" >"$work/server.log" 2>&1 &
pid=$!
sleep 1
EXPECT_MISMATCH=1 TEST_CA_DIR="$work/ca" TEST_PORT=18443 "${LUAJIT:-luajit}" tests/integration_tls_loopback.lua
