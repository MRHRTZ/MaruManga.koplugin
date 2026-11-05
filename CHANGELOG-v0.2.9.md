# MaruManga Downloader v0.2.9

## Changes
- Keep downloaded manga visible in Downloads by rebuilding manga groups and chapter rows from indexed CBZ metadata, even when completed queue entries were removed.
- Add long-press actions to pause, continue, cancel, or delete all downloads for a manga; prevent deleting an archive while a chapter download is active.
- Add confirmed single-chapter deletion. For combined manga CBZs, remove the selected chapter while preserving and verifying the other chapters, then update the library index and digest.
- Improve flat CBZ archive identification, merging, chapter lookup, and local archive integrity handling.
- Improve details and chapter dialogs on short screens, and make downloaded chapters offer open and verify actions.
- Fix Mangago Popular and Latest listing parsing, WEBTOON English/Indonesian listing and chapter parsing, and related source metadata compatibility.
- Fix in-app uninstall behavior and preserve the selected keep-data/delete-data choice, with clear next-restart feedback.
- Expand regression tests for archive rebuilding, metadata persistence, source parsing, and cleanup.

## Verification
- Native Windows test suite: 48 passed, 0 failed, 5 skipped (platform/product limitations).
- Android emulator: both in-app uninstall choices passed; Downloads archive recovery and deletion logic have regression coverage.
- Android UI could not seed a fresh deletion-flow fixture during this pass because Komiku search returned no matching titles. Kobo/e-ink checks remain for manual testing after release.
