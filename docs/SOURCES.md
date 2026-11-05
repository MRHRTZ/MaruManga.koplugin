# Source adapters

Repository entries are configuration only. Compatible catalog sources are installed as profiles; the plugin never executes source code fetched from a repository. Any number of compatible source profiles can use the shared generic adapter, subject to repository/catalog size limits.

Catalog entries may include an HTTPS `icon_url`. Same-site icon URLs are supported; the bundled catalog uses a 64-pixel favicon URL scoped to each source domain. The plugin includes the six current website favicons locally for immediate display and validates/caches metadata icons for other sources. Missing or unavailable icons fall back to the standard source row icon.

- `komiku`: Indonesian public catalog and chapter pages.
- `mangarock`: public MangaRock search, popular, latest, title, chapters and direct image pages.
- `mangamost`: the MangaMost JSON API identified in package `baca.read.komik.manga`.
- `mangago`: public `www.mangago.zone` HTML source; NSFW. Search uses `/r/l_search/`, popular uses `/topmanga/`, and work pages expose `#information` and `#chapter_table`. Chapter image URLs are decoded from the AES-encrypted page manifest. Certificate validation is skipped only for this exact source, while HTTPS and exact host allowlists remain enforced. Live pages and all six decoded image URLs were fetched; representative tall images were visually checked as continuous images without shuffled tiles.
- `webtoon`: public server-rendered English WEBTOON pages; the adapter does not run JavaScript.
- `webtoon_id`: public server-rendered Indonesian WEBTOON pages; the adapter handles Indonesian `/id/` title and `ep-…/viewer` routes, including episode numbers in the `episode_no` query parameter.
- `westmanga`: public Indonesian catalog at `www.westmanga.shop`. Search, popular, latest and paginated chapter lists use its JSON endpoint; title metadata and page images come from server-rendered pages. Chapter images use the exact `proxy.westmanga.shop` host and covers use `cdn.westmanga.shop`. The older `westmanga.site` landing page currently links to separate v1 mirrors.

The shared `generic` adapter supports complete declarative profiles for search/popular/latest URL patterns, result list selectors, manga metadata, chapter rows, image selectors, and ordinary page pagination. Additional repositories can add compatible IDs without a plugin code change. This does not mean arbitrary sites can be supported without limits: JavaScript execution, custom API signing, authenticated access, arbitrary AJAX chapter pagination, encrypted manifests and anti-bot challenges are not expressed by the current profile schema. Those require a reviewed bundled adapter and plugin release. Incomplete profiles are rejected rather than installed as functional sources.

Catalog and per-source metadata use semantic `MAJOR.MINOR.PATCH` versions. Strict validation still accepts old integer versions for compatibility with installed catalogs.
