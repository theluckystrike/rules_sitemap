# theluckystrike_rules_sitemap

Bazel rules that generate `sitemap.xml`, a sitemap index and `robots.txt` for a
statically built site, and fail the build when the result would be invalid.

Pure Starlark. No toolchain, no host tools, no network access, and no runtime
dependencies for consumers — the files are produced by `ctx.actions.write`
during the analysis phase.

## Why

A sitemap is usually the last artefact in a static-site build and the least
tested one. The failure mode is quiet: the file is served with HTTP 200, the
crawler parses what it can, and the entries it rejects simply never appear in
the index. The three mistakes that cause it are all mechanical:

* an unescaped `&` in a query string, which makes the document malformed XML;
* a `Sitemap:` line in `robots.txt` left pointing at the previous origin,
  because that one directive must be an absolute URL;
* duplicate `<loc>` entries, or more than 50,000 of them in one file.

These rules make each of those a build error instead of a silent deletion from
the index.

## Installation

```python
bazel_dep(name = "theluckystrike_rules_sitemap", version = "0.1.0")
```

## Usage

```python
load("@theluckystrike_rules_sitemap//sitemap:defs.bzl", "robots_txt", "sitemap_xml")

PAGES = [
    "/",
    "/pricing/",
    "/docs/getting-started/",
]

sitemap_xml(
    name = "sitemap",
    base_url = "https://example.com",
    pages = PAGES,
    lastmod = "2026-08-09",
    changefreq = "weekly",
    out = "sitemap.xml",
)

robots_txt(
    name = "robots",
    base_url = "https://example.com",
    allow = ["/"],
    disallow = ["/admin/"],
    sitemaps = ["/sitemap.xml"],
    out = "robots.txt",
)
```

`bazel build //:sitemap //:robots` produces:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://example.com/</loc>
    <lastmod>2026-08-09</lastmod>
    <changefreq>weekly</changefreq>
  </url>
  ...
</urlset>
```

```
User-agent: *
Allow: /
Disallow: /admin/

Sitemap: https://example.com/sitemap.xml
```

Page paths are root-relative, so the same `PAGES` list produces a correct
sitemap for a staging origin and for production; only `base_url` changes.

## Rules

### `sitemap_xml`

| Attribute | Type | Description |
| --- | --- | --- |
| `base_url` | string, required | Absolute origin the paths are joined onto. A trailing slash is ignored. |
| `pages` | string list, required | Root-relative page paths, each beginning with `/`. Must be unique. |
| `lastmod` | string | Optional W3C Datetime (`YYYY-MM-DD` or a full timestamp) written to every entry. |
| `changefreq` | string | Optional sitemap protocol change frequency. |
| `priority` | string | Optional priority between `0.0` and `1.0`. |
| `out` | output, required | The generated file. |

### `sitemap_index`

| Attribute | Type | Description |
| --- | --- | --- |
| `base_url` | string, required | Absolute origin the child sitemap paths are joined onto. |
| `sitemaps` | string list, required | Root-relative paths to the child sitemaps. |
| `lastmod` | string | Optional W3C Datetime written to every entry. |
| `out` | output, required | The generated file. |

### `robots_txt`

| Attribute | Type | Description |
| --- | --- | --- |
| `base_url` | string, required | Absolute origin used to make `Sitemap:` references absolute. |
| `user_agents` | string list | User agent tokens the group applies to. Defaults to `["*"]`. |
| `allow` | string list | Root-relative `Allow:` paths. |
| `disallow` | string list | Root-relative `Disallow:` paths. |
| `sitemaps` | string list | Root-relative paths to sitemap files. |
| `crawl_delay` | string | Optional `Crawl-delay:` value in seconds. |
| `out` | output, required | The generated file. |

## What is rejected at analysis time

| Input | Error |
| --- | --- |
| `base_url = "example.com"` | `base_url must start with http:// or https://` |
| `pages = ["about/"]` | `page paths must be root-relative and start with '/'` |
| the same path listed twice | `duplicate page path` |
| more than 50,000 pages in one sitemap | protocol limit, with a pointer to `sitemap_index` |
| `changefreq = "fortnightly"` | `changefreq must be one of always, hourly, ...` |
| `priority = "1.5"` | `priority must be between 0.0 and 1.0` |
| `lastmod = "09/08/2026"` | `lastmod must be a W3C Datetime such as 2026-08-09` |
| `disallow = ["draft/"]` | `disallow paths must be root-relative and start with '/'` |

## Example

`examples/site` is a complete, standalone Bazel module that builds a
three-page site's `sitemap.xml` and `robots.txt` and byte-compares both against
checked-in expected output:

```bash
cd examples/site
bazel test //...
```

## Tests

```bash
bazel test //...
```

19 tests: Starlark unit tests for the rendering helpers, golden byte-comparison
tests for each rule, and an analysis test for every rejected input above.

## Scope

These rules deliberately do not crawl a directory of HTML files to discover
pages. Which URLs belong in a sitemap is a routing decision that only the site
generator knows — trailing slashes, pagination, canonical duplicates,
`noindex` pages — so the page list is an explicit input. Generate it from
whatever produces your routes and pass it in.

## Licence

Apache License 2.0. See [LICENSE](LICENSE).
