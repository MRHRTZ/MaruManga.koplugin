# MaruManga Downloader for KOReader

[![Latest release](https://img.shields.io/github/v/release/MRHRTZ/MaruManga.koplugin?label=Download%20latest)](https://github.com/MRHRTZ/MaruManga.koplugin/releases/latest)

MaruManga Downloader saves manga chapters as one CBZ archive per manga, manages a local library, and checks bookmarked titles for new chapters. It is a native Lua KOReader plugin. Chapter reading uses KOReader's document reader and downloaded files, so reading is available offline.

## Install

1. Download the ZIP from [Latest release](https://github.com/MRHRTZ/MaruManga.koplugin/releases/latest).
2. Extract the `MaruManga.koplugin` folder into KOReader's `plugins` directory. The final path should end in `plugins/MaruManga.koplugin/main.lua` (do not leave an extra nested folder).
3. Restart KOReader.
4. Open **Tools > MaruManga Downloader**.

For Android, the plugin directory is normally under KOReader's application data. See [Development documentation](docs/README.md) for locating it and installing with ADB.

## Use

1. Open **Repositories** and refresh the default repository catalog. Install and enable **Komiku** if it is not already available. The default catalog is `https://raw.githubusercontent.com/MRHRTZ/maru-manga-repository/master/metadata.json`.
2. Open **Discover**, choose Search, Popular, or Latest updates, and open a manga card.
3. On the manga details page choose **Add to Library**.
4. Choose **Download All Chapters** to queue all missing chapters, or open **Chapters** and download selected chapters. Chapters merge into a single `manga.cbz` for that title. Downloads can be monitored, refreshed, paused, continued, or cancelled from **Downloads**.
5. Open **Library > Browse library**, select a title, then choose **Read Manga** to open its local CBZ in KOReader. The plugin blocks opening while that archive is being modified.
6. Use **Library > Check Updates** to compare bookmarked titles with their source. Already downloaded chapters are excluded from the new chapter count and can be queued for download.

**Settings > Network and storage** controls the download directory (default `./marumanga` under KOReader's data directory), concurrent downloads (default 2), timeout, retries, DNS, and optional SSL certificate validation override. Keep SSL verification enabled unless a trusted network requires otherwise.

## Update checks

**About > Check for updates** reads the version manifest at [release.json](https://raw.githubusercontent.com/MRHRTZ/MaruManga.koplugin/main/release.json). The manifest is intentionally a small, hardcoded raw GitHub endpoint; future releases update that file along with the GitHub release. When a newer version is found, the plugin reports the release page. The current update check does not silently replace plugin files.

## Repository sources

Source catalog data is maintained in [maru-manga-repository](https://github.com/MRHRTZ/maru-manga-repository). The plugin bundles reviewed source adapters; repository catalogs do not deliver or execute Lua code. Komiku is the active source. MangaRock and Mangago are listed as planned entries only. Mangago is marked NSFW. Source language and content tags are shown in repository management.

## Project docs

- [Development guide](docs/README.md)
- [Source compatibility](docs/SOURCE_COMPATIBILITY.md)
- [Attribution and licenses](docs/ATTRIBUTION.md)

See [KOReader's license](LICENSE) for this plugin's license terms.
