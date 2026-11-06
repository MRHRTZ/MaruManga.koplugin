# MaruManga Downloader v0.3.2

## Changes

- Added **Migrate** in Settings to export or import MaruManga settings, repositories, library and history, download queue, and indexed manga CBZ files in one archive.
- Added **Verify Download** to each manga's Library actions. It checks that manga's saved CBZ files against their recorded integrity metadata.
- Removed the chapter-language filter setting; chapter lists now follow each source's available chapters.
- Improved back navigation so returning from manga actions restores the previous screen instead of an outdated UI state.
- Improved chapter loading and pagination, including responsive chapter list sizing.
- Updated Komiku parser defaults for chapter and page selectors to match its current page structure.
- Changed the KOReader Tools entry to **MaruManga**.
- Updated installation and feature documentation.

## Notes

- The plugin remains focused on the local library and downloads; migration imports replace current MaruManga settings and add imported CBZ files to the selected storage folder.
- Source profile compatibility checks remain part of source installation from repositories.
