"""Starlark unit tests for the pure rendering helpers."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//sitemap/internal:robots_txt.bzl", "render_robots")
load("//sitemap/internal:sitemap_xml.bzl", "render_index", "render_urlset")
load("//sitemap/internal:xml.bzl", "escape_xml", "join_url", "normalize_base_url")

def _escape_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, "a&amp;b", escape_xml("a&b"))
    asserts.equals(env, "&lt;p&gt;", escape_xml("<p>"))
    asserts.equals(env, "&quot;q&quot;", escape_xml("\"q\""))
    asserts.equals(env, "it&apos;s", escape_xml("it's"))

    # The ampersand must be escaped first, otherwise the entities it
    # introduces get double escaped.
    asserts.equals(env, "&amp;lt;", escape_xml("&lt;"))
    return unittest.end(env)

escape_test = unittest.make(_escape_test_impl)

def _url_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, "https://example.com", normalize_base_url("https://example.com/"))
    asserts.equals(env, "https://example.com", normalize_base_url("https://example.com///"))
    asserts.equals(env, "http://example.com:8080", normalize_base_url("http://example.com:8080"))
    asserts.equals(env, "https://example.com/a/b/", join_url("https://example.com", "/a/b/"))
    return unittest.end(env)

url_test = unittest.make(_url_test_impl)

_EXPECTED_URLSET = """<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://example.com/</loc>
    <lastmod>2026-08-09</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>https://example.com/search?q=a&amp;p=2</loc>
    <lastmod>2026-08-09</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>
"""

def _urlset_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(
        env,
        _EXPECTED_URLSET,
        render_urlset(
            "https://example.com/",
            ["/", "/search?q=a&p=2"],
            "2026-08-09",
            "weekly",
            "1.0",
        ),
    )

    # Optional elements are omitted entirely rather than emitted empty.
    minimal = render_urlset("https://example.com", ["/"], "", "", "")
    asserts.true(env, "<lastmod>" not in minimal)
    asserts.true(env, "<changefreq>" not in minimal)
    asserts.true(env, "<priority>" not in minimal)
    asserts.true(env, "<loc>https://example.com/</loc>" in minimal)
    return unittest.end(env)

urlset_test = unittest.make(_urlset_test_impl)

_EXPECTED_INDEX = """<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap>
    <loc>https://example.com/sitemap-pages.xml</loc>
  </sitemap>
  <sitemap>
    <loc>https://example.com/sitemap-posts.xml</loc>
  </sitemap>
</sitemapindex>
"""

def _index_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(
        env,
        _EXPECTED_INDEX,
        render_index(
            "https://example.com",
            ["/sitemap-pages.xml", "/sitemap-posts.xml"],
            "",
        ),
    )
    return unittest.end(env)

index_test = unittest.make(_index_test_impl)

_EXPECTED_ROBOTS = """User-agent: *
Allow: /
Disallow: /draft/
Crawl-delay: 5

Sitemap: https://example.com/sitemap.xml
"""

def _robots_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(
        env,
        _EXPECTED_ROBOTS,
        render_robots(
            "https://example.com/",
            ["*"],
            ["/"],
            ["/draft/"],
            ["/sitemap.xml"],
            "5",
        ),
    )

    # The Sitemap directive is absolute even though the input path is not.
    moved = render_robots("https://staging.example.com", ["*"], [], [], ["/sitemap.xml"], "")
    asserts.true(env, "Sitemap: https://staging.example.com/sitemap.xml" in moved)
    return unittest.end(env)

robots_test = unittest.make(_robots_test_impl)

def render_test_suite(name):
    """Registers every Starlark unit test in this file.

    Args:
      name: name of the generated test suite.
    """
    unittest.suite(
        name,
        escape_test,
        url_test,
        urlset_test,
        index_test,
        robots_test,
    )
