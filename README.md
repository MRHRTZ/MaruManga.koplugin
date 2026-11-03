# MaruManga for KOReader

**Development version:** the browsing, downloads and reader integration are experimental and have not been verified together on a KOReader device. MangaDex requests from the development connection are currently blocked by a certificate redirect. This is not yet a release-ready manga reader.

## Installation for testing

1. Copy `MaruManga.koplugin` into KOReader's `plugins` directory, retaining all subdirectories.
2. Restart KOReader. Open the tools menu, choose **More tools**, then **MaruManga**.
3. In **Sources**, select MangaDex or add a source you are permitted to access. Search, select a title and chapter, and choose **Read** or **Download**.

The plugin uses KOReader's CBZ reader. Chapters are staged locally and a completed archive is published only if the filesystem supports a no-overwrite operation. The plugin does not intentionally replace existing downloads. A device may reject archive publication if neither safe operation is supported; this has not yet been tested on Android.

MangaDex chapter language defaults to English and can be changed in **Settings**. **Library**, **History**, and **Downloads** are available in the experimental menu. Reading progress, cancellation, and resume require device verification. Cancellation waits for an in-flight image request to finish or time out.

## HTML profiles

A Madara profile is supplied as a starting point and can be edited from **Sources**. Generic HTML profiles require search paths and CSS selectors to be configured. Only server-rendered HTML supported by KOReader's bundled `htmlparser` is handled. Configure image hosts explicitly if a source uses a different image domain. No JavaScript is executed. Sites differ, and no Madara or generic site has been verified.

The plugin does not bypass authentication, access restrictions, DRM, paywalls, or anti-bot challenges. It validates TLS certificates and fails closed when it cannot verify the hostname. If an access provider returns a certificate for another site, a request will fail.

## Tests and attribution

Fixture tests are in `tests/`; see [development notes](DEVELOPMENT.md) and [source compatibility](SOURCE_COMPATIBILITY.md) for their scope and current limitations. See [ATTRIBUTION.md](ATTRIBUTION.md) and [LICENSE](LICENSE). KOReader, MangaDex, source sites, and scanlation groups retain their respective rights and terms.

