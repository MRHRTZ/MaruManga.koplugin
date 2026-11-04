# Repository and source development

## Catalogs

The catalog repository root `metadata.json` defines a versioned repository with `id`, `name`, `author`, `version`, `status`, and a `sources` array. Each source declares an ID, name, per-source version, adapter, and optional languages and NSFW marker. Status values OK, Maintenance, and Error are recognized labels; unknown owner-supplied text is preserved and shown as Unknown by the UI.

The catalog URL must be HTTPS. Catalog IDs are stable and versions cannot move backwards. Per-repository source counts are calculated from catalog metadata and local installed profiles.

The default Maru repository catalog is version 1.13.0 and includes Komiku adapter version 1. Refresh the catalog after installation to discover it.

Use `adapter: "planned"` only for a source entry that is intentionally not installable yet. Planned sources are shown with language/NSFW tags and an unavailable-adapter note; they must not pretend to work. MangaRock and Mangago are planned catalog entries at this stage.

## Bundled adapters

The plugin executes only adapter code shipped under `sources/`. Komiku is the only source currently exposed for live requests. MangaDex was removed from the source repository and is blocked before network setup; its old plugin code remains only for offline parser and fixture tests. Madara and generic HTML adapters remain configurable for later testing. To add an adapter:

1. Define model and callback behavior independent of UI.
2. Parse fixture responses without a live website.
3. Add an explicit adapter allowlist and validated declarative profile schema.
4. Use the shared HTTPS transport, request timeout/retry behavior, and exact host allowlists.
5. Restrict redirects, image hosts, response sizes, selectors, and filenames.
6. Add mocked tests for malformed input, empty pages and HTTP errors.
7. Update `SOURCE_COMPATIBILITY.md`, attribution/license data, and the root repository catalog.

Never evaluate Lua, Kotlin, JavaScript, or scripts downloaded from a repository. A catalog entry cannot widen the plugin's network host allowlist arbitrarily. Do not bypass anti-bot controls, authentication, paywalls, DRM, or access restrictions.

## Komiku support

Komiku uses `api.komiku.org` for list/search HTML and `komiku.org` for manga details, chapters, and pages. Image requests are limited to a fixed allowlist. Requests send an Indonesian `Accept-Language` header; page images include the chapter referer. List, detail, and page-list requests are serialized at two requests per second and use the shared retry policy. Image downloads use the app's configured download concurrency. Catalog metadata cannot override the Komiku API/base origins or add arbitrary image hosts. JavaScript execution, dynamic challenges, authentication, and access-control bypass are unsupported.

This port selectively adapts public behavior from Keiyoushi's Komiku extension, under Apache-2.0. See `ATTRIBUTION.md`, `third_party/keiyoushi/LICENSE`, and the mirror in `maru-manga-repository/komiku/`. The plugin executes only its bundled Lua adapter.

## Language and NSFW tags

Use ISO-like lowercase language tags supported by the source, e.g. `id`, `en`, `ja`; use `multi` only when a source genuinely spans languages. A source supporting several languages may list several. Set `nsfw: true` only when its catalog entry may expose adult content. The UI must preserve the marker and display it in the repository source row and detail.

## Repository maintenance

Increase the catalog semantic version on any published metadata change and increment a source's integer version when its profile or behavior changes. Keep entry IDs stable. Test the JSON against `core/repositories.lua` before publishing. Keep author and source licenses in the repository's attribution files.
