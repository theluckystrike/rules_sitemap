"""Public API of theluckystrike_rules_sitemap.

Three rules, all pure Starlark:

  * `sitemap_xml`    - a sitemaps.org `urlset` document
  * `sitemap_index`  - a sitemaps.org `sitemapindex` document
  * `robots_txt`     - a `robots.txt` with absolute `Sitemap:` references

Load them from this file; everything under `//sitemap/internal` is private and
may change without a compatibility level bump.
"""

load("//sitemap/internal:robots_txt.bzl", _robots_txt = "robots_txt")
load(
    "//sitemap/internal:sitemap_xml.bzl",
    _sitemap_index = "sitemap_index",
    _sitemap_xml = "sitemap_xml",
)

sitemap_xml = _sitemap_xml
sitemap_index = _sitemap_index
robots_txt = _robots_txt
