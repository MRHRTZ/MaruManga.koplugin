# MaruManga Downloader v0.2.7

## Fixes

- Fixed manga details crashing when a source returns genres as structured records instead of plain text.
- Fixed chapter-list pagination overflowing KOReader's dialog on pages with both Previous and Next controls.
- Added protected page-turn handling so unexpected KOReader widget errors show a traceback dialog instead of closing the plugin.
- Made Previous and Next pagination icons use matching circular arrows.
- Replaced the chapter sort row's info icon with a sort icon.

## Verification

- MangaRock search, manga details, and chapter pagination were exercised on the KOReader Android emulator, including moving to page 2 and back to page 1.
- Automated test suite: 48 passed, 0 failed, 5 skipped. Skips require POSIX/KOReader-host support or cover removed MangaDex adapters.
- Physical Kobo/e-ink verification remains outstanding.
