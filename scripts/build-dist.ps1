param(
    [string]$Version = "",
    [string]$PluginDirectory = (Split-Path $PSScriptRoot -Parent),
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$PluginDirectory = [System.IO.Path]::GetFullPath($PluginDirectory)
if (!$OutputDirectory) { $OutputDirectory = Join-Path $PluginDirectory "dist" }
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$metadataPath = Join-Path $PluginDirectory "_meta.lua"
if (!(Test-Path -LiteralPath $metadataPath -PathType Leaf)) { throw "Plugin metadata not found: $metadataPath" }
$metadata = Get-Content -LiteralPath $metadataPath -Raw
if (!$Version) {
    if ($metadata -notmatch 'version\s*=\s*["'']([^"'']+)["'']') { throw "Could not read plugin version from _meta.lua" }
    $Version = $Matches[1]
}
if ($metadata -notmatch ('version\s*=\s*["'']' + [regex]::Escape($Version) + '["'']')) {
    throw "Requested version $Version does not match _meta.lua"
}

$leaf = Split-Path $PluginDirectory -Leaf
$archiveRoot = "$leaf/"
$zipPath = Join-Path $OutputDirectory "marumanga.koplugin.v$Version.zip"
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

$stream = [System.IO.File]::Open($zipPath, [System.IO.FileMode]::CreateNew)
try {
    $archive = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        Get-ChildItem -LiteralPath $PluginDirectory -File -Recurse -Force |
            Where-Object { $_.FullName -notlike "$OutputDirectory\*" -and $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.Name -notmatch '^CHANGELOG-v.*\.md$' -and $_.Name -notin @('device-post-push-menu.png', 'device-settings-temp.lua', 'device-storage-layout.png') } |
            Sort-Object FullName |
            ForEach-Object {
                $relative = $_.FullName.Substring($PluginDirectory.Length).TrimStart('\', '/') -replace '\\', '/'
                if (!$relative -or $relative.StartsWith('/') -or $relative -match '(^|/)\.\.?(/|$)') {
                    throw "Unsafe archive entry path: $relative"
                }
                $entryName = $archiveRoot + $relative
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $archive, $_.FullName, $entryName, [System.IO.Compression.CompressionLevel]::Optimal
                ) | Out-Null
            }
    } finally {
        $archive.Dispose()
    }
} finally {
    $stream.Dispose()
}

$check = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $names = @($check.Entries | ForEach-Object FullName)
    if ($names | Where-Object { $_.Contains('\') }) { throw "ZIP contains a Windows backslash in an entry path" }
    if ($names -notcontains "${archiveRoot}_meta.lua" -or $names -notcontains "${archiveRoot}main.lua" -or $names -notcontains "${archiveRoot}core/all_source_search.lua") {
        throw "ZIP is missing required plugin files"
    }
    if ($names | Where-Object { $_ -notlike "$archiveRoot*" }) { throw "ZIP contains files outside the plugin directory" }
} finally {
    $check.Dispose()
}

Write-Output "Built and validated $zipPath"
