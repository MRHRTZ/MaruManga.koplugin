# Structure and UI

## Directory map

| Path | Purpose |
| --- | --- |
| `main.lua` | KOReader plugin registration, native menus, workflow wiring |
| `core/` | Download queue, repository catalog validation, library updates and archives |
| `network/` | HTTPS transport, host validation, cookies, image downloads |
| `reader/` | Page staging, image validation, CBZ creation, local archive safety |
| `sources/` | Bundled trusted adapters and parsers |
| `storage/` | LuaSettings persistence and validation |
| `tests/` | Mocked source, storage, network and archive tests |
| `docs/` | Contributor and device testing instructions |
| `images/maru-manga-reader.png` | Transparent square mascot artwork used in the home dialog |
| `images/menu/` | Colored SVG icons for home and actionable rows |

## KOReader UI conventions

`MaruManga:init()` registers the plugin with `self.ui.menu:registerToMainMenu(self)`; `addToMainMenu` uses `sorting_hint = "tools"` so it appears directly in Tools. Keep navigation in KOReader's native widgets. The plugin uses one rounded home dialog and replaces its added widgets when moving between pages. The home page shows the transparent mascot and a right-side X; submenu pages remove the mascot and X and place a back button at the upper left. `ui/main_menu.lua` maintains a page stack and paginates long item lists in place. The mascot PNG is square; keep its viewport square and use `scale_factor = 0` to preserve its aspect ratio. Native search/input dialogs may overlay the panel, while their resulting lists return to the same panel.

The main menu groups Discover and Library, Repositories, then Downloads, Settings, and About. Search and update checking live inside the Library submenu. About shows the plugin version, author, update date, and latest GitHub release status. Repository details provide source search by name or ID, match counts, a clear action and in-panel pagination; source install/enable/disable/uninstall stays inside its repository.

Actionable rows display distinct colored SVG icons; library entries use a larger three-line row with separate title, status/genres, chapter counts and an explicit latest/update/check label. Green check, yellow warning and blue clock icons retain distinct shapes in grayscale. Empty-state rows remain plain text. Use separators to group related actions. Do not use animation or custom rendering loops.

KOReader CoverBrowser currently modifies the FileManager's book and directory display modes. It has no public API for arbitrary plugin-owned manga records. The library therefore uses a native list with cover metadata/status text; downloaded CBZ files may be viewed through FileManager's CoverBrowser mosaic. Do not call CoverBrowser private methods or patch its internals.

## Persistence and downloads

LuaSettings stores settings, repository catalogs, library and queue metadata. The library persists the successful source chapter count, the exact count of chapters missing locally, and a timestamp per title after a fully paginated source check. Older sync records without a missing count show `Check Updates` until refreshed. The default download root is KOReader data storage `marumanga/`; settings accept an absolute path without traversal components. The persisted queue runs up to the configured 1–5 concurrent chapter jobs (default 2), but schedules at most one active job per manga because all chapters merge into one uniquely named CBZ at the root of the selected storage folder. Covers, source icons, cache and staged images go under `.marumanga/` in that folder. The CBZ builder stages and validates page images, merges prior archive entries with the new chapter, naturally sorts chapter paths, verifies the replacement, and atomically publishes it. Existing nested manga and per-chapter archives are migrated into the direct-folder archive when a missing chapter is next downloaded. `ignore_ssl_certificates` defaults to false; when enabled, `secure_request.lua` skips CA-chain and hostname validation while continuing to require HTTPS and an allowed source host. Enable it only on a trusted network. DNS mode is plugin-local: Auto keeps OS DNS; Google, Cloudflare and a manually entered IPv4 server are used for the plugin's HTTPS requests only. KOReader/Android system DNS is unchanged. The TCP connection uses the resolved IPv4 address, while TLS SNI and certificate validation still use the original hostname.

Each manga CBZ is placed directly in the configured Storage folder and has a sanitized title plus source and manga ID in its filename. Covers, cache, image staging, and other plugin-owned files live under the hidden `.marumanga/` subfolder. Each CBZ contains one sanitized folder per chapter and numbered page images beneath it. KOReader's bundled MuPDF reader interprets directory names in CBZ paths as native TOC chapter headings, targeting that chapter's first page. The archive validator accepts both multi-chapter titled folders and legacy root-level page entries.

## Styling limits

KOReader uses native e-ink widgets and device theme colors. Keep text labels clear in grayscale. The home dialog uses a modest rounded frame, while full-page menus retain the square native treatment. The mascot is a small static raster image.
