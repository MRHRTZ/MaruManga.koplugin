param(
    [string]$LuaJit = 'C:\Program Files\Tools\msys2\ucrt64\bin\luajit.exe',
    [string]$Dependencies = "$env:LOCALAPPDATA\MaruManga\test-deps",
    [string]$Pattern = 'test_*.lua',
    [string]$KOReaderBase = '',
    [string]$KOReaderRoot = ''
)
$ErrorActionPreference = 'Stop'
$oldPath = $env:LUA_PATH
$oldCPath = $env:LUA_CPATH
$oldBase = $env:KOREADER_BASE
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    $env:LUA_PATH = "$Dependencies/?.lua;$Dependencies/socket/?.lua;$Dependencies/?/init.lua;$oldPath;;"
    if ($KOReaderBase) { $env:LUA_PATH = "$KOReaderBase/?.lua;$KOReaderBase/common/?.lua;$env:LUA_PATH"; $env:KOREADER_BASE = $KOReaderBase }
    if ($KOReaderRoot) { $env:LUA_PATH = "$KOReaderRoot/frontend/?.lua;$env:LUA_PATH" }
    $env:LUA_CPATH = "$Dependencies/?.dll;$oldCPath;;"
    $tests = @(Get-ChildItem tests -Filter $Pattern | Sort-Object Name)
    if (!$tests.Count) { throw "No tests match $Pattern" }
    $passed = 0
    $failed = 0
    $skipped = 0
    foreach ($test in $tests) {
        $reason = switch ($test.Name) {
            'test_exclusive_copy.lua' { 'requires POSIX open/link symbols' }
            'test_plugin_integration.lua' { 'settings fixture requires POSIX overwrite-rename behavior' }
            'test_file_digest.lua' { if (!$env:KOREADER_BASE) { 'set -KOReaderBase for the actual SHA module' } }
            'test_mangadex_parser.lua' { 'MangaDex adapter was removed from the product source set' }
            'test_mangadex_source.lua' { 'MangaDex adapter was removed from the product source set' }
        }
        if ($reason) { $skipped++; Write-Host "SKIP $($test.Name): $reason"; continue }
        & $LuaJit $test.FullName
        if ($LASTEXITCODE -eq 0) { $passed++ } else { $failed++; Write-Host "FAIL $($test.Name)" }
    }
    Write-Host "$passed passed; $failed failed; $skipped skipped. Native Windows host only; no ADB."
    if ($failed) { throw "$failed test files failed" }
} finally {
    Pop-Location
    $env:LUA_PATH = $oldPath
    $env:LUA_CPATH = $oldCPath
    $env:KOREADER_BASE = $oldBase
}
