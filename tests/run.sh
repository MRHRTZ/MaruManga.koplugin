#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
lua_path="${LUA_PATH:-;;}"
if [ -n "${KOREADER_ROOT:-}" ]; then
    lua_path="$KOREADER_ROOT/frontend/?.lua;$lua_path"
fi
if [ -n "${KOREADER_BASE:-}" ]; then
    lua_path="$KOREADER_BASE/?.lua;$KOREADER_BASE/common/?.lua;$lua_path"
fi
if [ -n "${KOREADER_TEST_LUA_PATH:-}" ]; then
    lua_path="$KOREADER_TEST_LUA_PATH;$lua_path"
fi
LUA_PATH="$lua_path"
export LUA_PATH
for test_file in tests/test_*.lua; do
    case "$test_file" in
        tests/test_file_digest.lua|tests/test_generic_parser.lua|tests/test_generic_source.lua|tests/test_komiku_source.lua|tests/test_madara_parser.lua|tests/test_plugin_integration.lua)
            if [ -z "${KOREADER_BASE:-}" ]; then
                printf 'SKIP %s (set KOREADER_BASE to a KOReader source tree)\n' "$test_file"
                continue
            fi
            ;;
    esac
    if [ ! -f "$test_file" ]; then
        printf 'ERROR missing test file: %s\n' "$test_file" >&2
        exit 1
    fi
    "${LUAJIT:-luajit}" "$test_file"
done
