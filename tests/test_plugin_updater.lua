local Updater = dofile("core/plugin_updater.lua")

assert(Updater.isNewer("0.2.2", "0.2.3"))
assert(Updater.isNewer("0.2.9", "0.3.0"))
assert(not Updater.isNewer("0.2.2", "0.2.2"))
assert(not Updater.isNewer("0.3.0", "0.2.9"))
assert(not Updater.isNewer("unknown", "0.2.3"))

assert(Updater.validateURL("https://github.com/MRHRTZ/MaruManga.koplugin/releases/download/v1.0.0/plugin.zip") == "github.com")
assert(Updater.validateURL("https://objects.githubusercontent.com/asset.zip") == "objects.githubusercontent.com")
assert(not Updater.validateURL("http://github.com/MRHRTZ/plugin.zip"))
assert(not Updater.validateURL("https://example.org/plugin.zip"))
assert(not Updater.validateURL("https://github.com@evil.example/plugin.zip"))
assert(not Updater.validateURL("https://github.com/MRHRTZ/plugin.zip#fragment"))

local redirected, host = Updater.resolveRedirect(
    "https://github.com/MRHRTZ/plugin/releases/latest",
    "https://release-assets.githubusercontent.com/asset.zip"
)
assert(redirected == "https://release-assets.githubusercontent.com/asset.zip")
assert(host == "release-assets.githubusercontent.com")
assert(not Updater.resolveRedirect("https://github.com/MRHRTZ/plugin", "http://evil.example/file.zip"))
assert(not Updater.resolveRedirect("https://github.com/MRHRTZ/plugin", "https://evil.example/file.zip"))

assert(Updater.safeRelative("core/all_source_search.lua"))
assert(Updater.safeRelative("images/menu/search.svg"))
assert(not Updater.safeRelative("../main.lua"))
assert(not Updater.safeRelative("core/../../main.lua"))
assert(not Updater.safeRelative("core\\all_source_search.lua"))
assert(not Updater.safeRelative("C:/main.lua"))
assert(not Updater.safeRelative("/main.lua"))

print("Plugin updater policy checks passed")
