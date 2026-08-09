"""Shared helpers for building sitemap and robots output.

Everything in this file is pure Starlark and runs during the analysis phase, so
the generated files are produced by `ctx.actions.write` with no toolchain, no
host tools and no network access.
"""

_ESCAPES = [
    ("&", "&amp;"),
    ("<", "&lt;"),
    (">", "&gt;"),
    ("\"", "&quot;"),
    ("'", "&apos;"),
]

# https://www.sitemaps.org/protocol.html
CHANGEFREQS = [
    "always",
    "hourly",
    "daily",
    "weekly",
    "monthly",
    "yearly",
    "never",
]

MAX_URLS_PER_SITEMAP = 50000

def escape_xml(value):
    """Escapes the five XML predefined entities.

    The sitemap protocol requires entity-escaped URLs; an unescaped `&` in a
    query string is the single most common way to produce a sitemap that
    Search Console rejects as malformed.

    Args:
      value: string to escape.

    Returns:
      The escaped string.
    """
    if type(value) != "string":
        fail("escape_xml expects a string, got %s" % type(value))
    out = value
    for (raw, entity) in _ESCAPES:
        out = out.replace(raw, entity)
    return out

def normalize_base_url(base_url):
    """Validates an origin and strips any trailing slash.

    Args:
      base_url: absolute origin, for example `https://example.com`.

    Returns:
      The origin without a trailing slash.
    """
    if not base_url.startswith("http://") and not base_url.startswith("https://"):
        fail("base_url must start with http:// or https://, got %r" % base_url)
    if " " in base_url:
        fail("base_url must not contain spaces, got %r" % base_url)
    stripped = base_url.rstrip("/")
    if stripped in ["http:/", "https:/", "http:", "https:"]:
        fail("base_url must contain a host, got %r" % base_url)
    return stripped

def join_url(base_url, path):
    """Joins a validated origin and a root-relative path.

    Args:
      base_url: origin already passed through `normalize_base_url`.
      path: root-relative path beginning with `/`.

    Returns:
      The absolute URL.
    """
    if not path.startswith("/"):
        fail("page paths must be root-relative and start with '/', got %r" % path)
    if " " in path:
        fail("page paths must not contain spaces, got %r" % path)
    return base_url + path

def check_unique(paths):
    """Fails if the same path is listed twice.

    Duplicate `<loc>` entries are a protocol violation and silently waste
    crawl budget, so this is an error rather than a warning.

    Args:
      paths: list of path strings.
    """
    seen = {}
    for path in paths:
        if path in seen:
            fail("duplicate page path %r; every <loc> in a sitemap must be unique" % path)
        seen[path] = True

def check_count(paths):
    """Fails if the URL count exceeds the sitemap protocol limit.

    Args:
      paths: list of path strings.
    """
    if len(paths) > MAX_URLS_PER_SITEMAP:
        fail(
            "a single sitemap may contain at most %d URLs, got %d; split the " %
            (MAX_URLS_PER_SITEMAP, len(paths)) +
            "pages across several sitemap_xml targets and combine them with sitemap_index",
        )

def check_changefreq(changefreq):
    """Validates the optional `changefreq` value.

    Args:
      changefreq: one of the sitemap protocol values, or the empty string.
    """
    if changefreq and changefreq not in CHANGEFREQS:
        fail("changefreq must be one of %s, got %r" % (", ".join(CHANGEFREQS), changefreq))

def check_priority(priority):
    """Validates the optional `priority` value.

    Args:
      priority: decimal string between 0.0 and 1.0, or the empty string.
    """
    if not priority:
        return
    for char in priority.elems():
        if char not in "0123456789.":
            fail("priority must be a decimal number between 0.0 and 1.0, got %r" % priority)
    if priority.count(".") > 1:
        fail("priority must be a decimal number between 0.0 and 1.0, got %r" % priority)
    value = float(priority)
    if value < 0.0 or value > 1.0:
        fail("priority must be between 0.0 and 1.0, got %r" % priority)

def check_lastmod(lastmod):
    """Validates the optional `lastmod` value against W3C Datetime.

    Only the shapes the sitemap protocol actually accepts are allowed: a bare
    `YYYY-MM-DD` date, or a full timestamp beginning with one.

    Args:
      lastmod: date or timestamp string, or the empty string.
    """
    if not lastmod:
        return
    if len(lastmod) < 10:
        fail("lastmod must be a W3C Datetime such as 2026-08-09, got %r" % lastmod)
    date = lastmod[:10]
    if date[4] != "-" or date[7] != "-":
        fail("lastmod must be a W3C Datetime such as 2026-08-09, got %r" % lastmod)
    for index in [0, 1, 2, 3, 5, 6, 8, 9]:
        if not date[index].isdigit():
            fail("lastmod must be a W3C Datetime such as 2026-08-09, got %r" % lastmod)
    if len(lastmod) > 10 and lastmod[10] != "T":
        fail("lastmod must be a W3C Datetime such as 2026-08-09, got %r" % lastmod)
