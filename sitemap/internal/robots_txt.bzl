"""Implementation of the `robots_txt` rule."""

load(":xml.bzl", "join_url", "normalize_base_url")

def _check_directive(kind, value):
    if not value.startswith("/") and value != "*":
        fail("%s paths must be root-relative and start with '/', got %r" % (kind, value))
    if " " in value:
        fail("%s paths must not contain spaces, got %r" % (kind, value))
    if "\n" in value:
        fail("%s paths must not contain newlines, got %r" % (kind, value))

def render_robots(base_url, user_agents, allow, disallow, sitemaps, crawl_delay):
    """Renders a robots.txt document.

    Args:
      base_url: absolute origin used to make sitemap references absolute.
      user_agents: list of user agent tokens the group applies to.
      allow: list of root-relative Allow paths.
      disallow: list of root-relative Disallow paths.
      sitemaps: list of root-relative paths to sitemap files.
      crawl_delay: optional Crawl-delay value in seconds.

    Returns:
      The complete robots.txt document as a string, newline terminated.
    """
    origin = normalize_base_url(base_url)
    if not user_agents:
        fail("robots_txt requires at least one user_agent")
    for path in allow:
        _check_directive("allow", path)
    for path in disallow:
        _check_directive("disallow", path)
    for path in sitemaps:
        if not path.startswith("/"):
            fail("sitemaps must be root-relative and start with '/', got %r" % path)

    lines = []
    for agent in user_agents:
        if " " in agent:
            fail("user agent tokens must not contain spaces, got %r" % agent)
        lines.append("User-agent: %s" % agent)
    for path in allow:
        lines.append("Allow: %s" % path)
    for path in disallow:
        lines.append("Disallow: %s" % path)
    if crawl_delay:
        for char in crawl_delay.elems():
            if char not in "0123456789.":
                fail("crawl_delay must be a number of seconds, got %r" % crawl_delay)
        lines.append("Crawl-delay: %s" % crawl_delay)
    if sitemaps:
        lines.append("")
        for path in sitemaps:
            lines.append("Sitemap: %s" % join_url(origin, path))
    return "\n".join(lines) + "\n"

def _robots_txt_impl(ctx):
    content = render_robots(
        ctx.attr.base_url,
        ctx.attr.user_agents,
        ctx.attr.allow,
        ctx.attr.disallow,
        ctx.attr.sitemaps,
        ctx.attr.crawl_delay,
    )
    ctx.actions.write(output = ctx.outputs.out, content = content)
    return [DefaultInfo(files = depset([ctx.outputs.out]))]

robots_txt = rule(
    implementation = _robots_txt_impl,
    doc = """Generates a `robots.txt` file with absolute `Sitemap:` references.

The `Sitemap:` directive is the one line in robots.txt that must carry an
absolute URL; hand-written files routinely get it wrong when a site moves
origin. Here the sitemap paths are root-relative and joined onto `base_url`,
so the same target produces a correct file for every origin it is built for.""",
    attrs = {
        "base_url": attr.string(
            mandatory = True,
            doc = "Absolute origin used to make the `Sitemap:` references absolute.",
        ),
        "user_agents": attr.string_list(
            default = ["*"],
            doc = "User agent tokens the group applies to.",
        ),
        "allow": attr.string_list(
            doc = "Root-relative `Allow:` paths.",
        ),
        "disallow": attr.string_list(
            doc = "Root-relative `Disallow:` paths.",
        ),
        "sitemaps": attr.string_list(
            doc = "Root-relative paths to sitemap files, written as absolute `Sitemap:` URLs.",
        ),
        "crawl_delay": attr.string(
            doc = "Optional `Crawl-delay:` value in seconds.",
        ),
        "out": attr.output(
            mandatory = True,
            doc = "The generated file, conventionally named `robots.txt`.",
        ),
    },
)
