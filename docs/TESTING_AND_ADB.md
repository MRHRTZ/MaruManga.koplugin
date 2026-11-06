# Tests and Android deployment

## Automated tests

Settings are grouped into **Network**, **Download**, **Storage**, **Migrate**, and **Uninstall**. Migrate exports/imports plugin settings, repositories, library/history, queue metadata, and indexed manga CBZ files. Import replaces current plugin state and restores CBZs in the currently selected storage folder. Repository source profiles are checked when the user installs them. Open a title in Library and choose **Verify Download** to check that manga's indexed CBZ hashes and report damaged, missing, incomplete, or unverified chapters. Chapter lists are shown as provided by each source; source language tags identify the catalog language but do not filter chapter results. DNS settings are plugin-local. Open **Settings → Network → DNS resolver** to choose Auto, Google, Cloudflare or Other. Selecting Other asks for the resolver IPv4 address. Auto restores the device resolver. Google, Cloudflare and manual DNS use direct UDP on port 53 for MaruManga requests only; choose Auto on networks that block custom DNS. **Settings → Download** controls concurrent downloads (default 2). **Settings → Storage** displays the active folder, opens KOReader's folder picker, and offers Restore default folder when a custom path is set. The default is `marumanga` under KOReader's data directory. Manga CBZ files are stored directly in the selected folder. Covers, cache, source icons and image staging files are stored in `.marumanga/` beneath that folder. Library and queue settings remain in KOReader's LuaSettings file. Android verification covered the DNS selection and the folder picker/default path; a live DNS query through a public resolver remains an integration check.

Run the Lua test suite from the plugin directory in an environment with LuaJIT and KOReader-compatible bundled dependencies:

```sh
sh tests/run.sh
LUAJIT=luajit sh tests/integration_tls_loopback.sh
TEST_FULL=1 sh tests/integration_mangadex_loopback.sh
```

The tests use local fixtures; routine test runs do not require live manga sites. Keep network tests restricted to a loopback server. Validate the repository JSON with the unit tests before publishing. Test queue behavior at concurrency 1 and 2, duplicate jobs, cancellation, failures, and settings rollback.

### Native Windows host tests (no ADB)

GCC 15.2 and Clang 21.1 were already installed. LuaJIT was installed into the existing MSYS2 UCRT64 environment using `pacman -S --needed --noconfirm mingw-w64-ucrt-x86_64-luajit`. LuaSocket DLLs were compiled with GCC against that LuaJIT; HTML parser and LuaSocket modules are under `%LOCALAPPDATA%/MaruManga/test-deps`, outside the plugin.

Run `./tests/run-windows.ps1 -KOReaderBase <koreader-base-source-directory>` from the plugin directory. `-LuaJit`, `-Dependencies`, `-KOReaderRoot` and `-Pattern` override paths or select tests. The default executable is `C:\Program Files\Tools\msys2\ucrt64\bin\luajit.exe`. Dependencies must provide `htmlparser.lua`, `htmlparser/`, `socket.lua`, `socket/` (including `core.dll` and `url.lua`) and `mime` modules. The runner restores the calling environment afterward.

On 2026-11-05, the latest full native Windows run had 43 test files pass, zero failures, and five skips: POSIX exclusive-copy symbols, a SHA fixture requiring the KOReader source tree, the UI integration fixture's POSIX overwrite-rename behavior, and the two MangaDex adapter tests whose source was removed. The MangaMost, Mangago, MangaRock, WEBTOON, WestManga and repository test files pass individually. Live Mangago requests used a source-scoped certificate bypass, decoded six image URLs, and downloaded six valid JPEGs. WestManga search, popular, latest, paginated chapter API and one JPEG reader image passed live HTTP checks. This host result does not replace Android, Linux archive integration or e-ink testing; no ADB was used.

## Deploy to the configured Android emulator

Use the explicitly configured target `emulator-5556`; check it first:

```powershell
adb -s emulator-5556 get-state
adb -s emulator-5556 shell ls /sdcard/koreader/plugins
```

Push the whole plugin directory so nested modules and the image are included:

```powershell
adb -s emulator-5556 shell mkdir -p /sdcard/koreader/plugins
adb -s emulator-5556 push .\MaruManga.koplugin\ /sdcard/koreader/plugins/
adb -s emulator-5556 shell am force-stop org.koreader.launcher
adb -s emulator-5556 shell monkey -p org.koreader.launcher 1
```

If the device uses another KOReader package or storage location, inspect `adb shell pm list packages | Select-String koreader` and KOReader's settings rather than guessing. Never push into KOReader's application/core directories.

## UI Automator-first inspection

After restart, inspect the hierarchy before interacting:

```powershell
adb -s emulator-5556 shell uiautomator dump /sdcard/window.xml
adb -s emulator-5556 pull /sdcard/window.xml .\window.xml
Get-Content .\window.xml
```

Use `adb shell input tap X Y`, `adb shell input swipe X1 Y1 X2 Y2`, and `adb shell input text '...'` for actions. Batch predictable actions, then dump the hierarchy again after page transitions. If KOReader custom menus are not exposed to UI Automator, capture one screenshot for the visual state and use coordinates. Avoid repetitive screenshots.

Collect logs only for diagnosis:

```powershell
adb -s emulator-5556 logcat -d -v time | Select-String -Pattern 'KOReader|Lua|MaruManga|FATAL EXCEPTION'
adb -s emulator-5556 shell ls /sdcard/koreader/crash.log
```

When a KOReader log path differs on a device, inspect its data directory. Redact user tokens/cookies and remove temporary hierarchy files after review.

## Manual acceptance path

1. Confirm the Tools menu contains **MaruManga Downloader** directly.
2. Verify home order, separators, centered mascot image and left-chevron back behavior.
3. Add/refresh a repository; edit title/URL; reset title from metadata; inspect delete confirmation.
4. Open a repository, inspect language/NSFW tags, verify Komiku is the only available live source, and exercise bulk actions with a fixture catalog.
5. Search and save a manga; open Library, search, and Check Updates.
6. Queue several chapters; verify two jobs can run concurrently and that the setting changes the limit.
7. On the chapter list, use the top-right download-all action. During chapter-list preparation, confirm Back returns to the chapter page, X closes the plugin panel, and Cancel aborts the request without queueing late results. On completion, confirm all missing source chapters are queued, downloaded or already queued chapters are skipped, and one `manga.cbz` is created for the title. Download an additional chapter individually and confirm it merges into that same CBZ.
8. Confirm same-manga jobs run sequentially while other manga can use the configured concurrency. Verify archive ordering with chapters 2 and 10, and confirm the native Table of contents shows each chapter title at its first page.
9. Verify completed CBZ integrity, retry/cancel behavior, and that deleting the manga archive clearly removes all chapters in it. Test one older per-chapter archive and confirm it migrates when downloading a missing chapter.
10. For Popular, Latest, Search and bulk download, confirm the text loading dialog remains visible until completion or error. Confirm tapping outside does not close MaruManga Downloader, its X does, and long menus scroll while the dialog stays centered.
11. Open **Downloads** with both an empty queue and a large queue. Confirm the empty state, visible progress, and at most eight download rows per page; use Next/Previous, Refresh, Back, and X without closing KOReader unexpectedly.
12. Open a manga's **Chapters** page with more than one screen of chapters. Verify it stays open, paginates, shows the `Page n / total` heading, and its Back and X controls work.
13. Verify Settings shows Network, Download, Storage, Migrate, and Uninstall in that order. Open Storage, confirm the default folder is shown without an empty placeholder, choose a folder, then restore the default. Export data to a chosen folder; verify the resulting ZIP includes the manifest and indexed CBZs. Import that ZIP into a clean test profile and check repositories, library/history, queue metadata, and manga CBZ reads. Open a downloaded title from Library and run its **Verify Download** action against valid and deliberately damaged test archives. Confirm unsupported or malformed source profiles are rejected at install time. Test uninstall with Cancel at each confirmation; do not remove the plugin during routine UI verification.

Record device model, KOReader version, source/catalog revision, network state, and any unverified step in the release report.
