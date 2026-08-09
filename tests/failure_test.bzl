"""Analysis tests asserting that bad input is rejected with a useful message.

Every one of these inputs produces a sitemap or robots.txt that a search
engine silently discards, so the rules turn them into build errors instead.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _expect(msg):
    def _impl(ctx):
        env = analysistest.begin(ctx)
        asserts.expect_failure(env, msg)
        return analysistest.end(env)

    return analysistest.make(_impl, expect_failure = True)

relative_base_url_test = _expect("base_url must start with http:// or https://")
relative_page_test = _expect("page paths must be root-relative and start with '/'")
duplicate_page_test = _expect("duplicate page path")
bad_changefreq_test = _expect("changefreq must be one of")
bad_priority_test = _expect("priority must be between 0.0 and 1.0")
bad_lastmod_test = _expect("lastmod must be a W3C Datetime")
empty_index_test = _expect("sitemap_index requires at least one child sitemap")
bad_disallow_test = _expect("disallow paths must be root-relative and start with '/'")
