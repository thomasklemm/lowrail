### Restore RemoteIp::GetIp#filter_proxies as deprecated

#56805 made computing the remote IP noticeably cheaper by replacing `filter_proxies` with `first_non_proxy`, which stops at the first IP that isn't a trusted proxy. Thanks for that. On 8-1, though, `filter_proxies` was marked `# :doc:`, so it showed up in the API docs for extensions, and it was removed without a deprecation.

Mastodon is one of those extensions. Its `lib/action_dispatch/remote_ip_extensions.rb` prepends its own `calculate_ip` to `GetIp` and calls `filter_proxies([remote_addr] + ips).first`. On main, every request through that code raises `NoMethodError`, and most of Mastodon's request specs fail that way.

This adds `filter_proxies(ips)` back as a private `:doc:` method with 8-1's body. It returns every IP that isn't a trusted proxy, in order, and warns through `ActionDispatch.deprecator` that it will be removed in Rails 9.0, pointing to `first_non_proxy`. The optimized `calculate_ip` path is unchanged and doesn't call it.

The test checks that IPv4, IPv6 and Regexp proxies give the same results as 8-1-stable, and that each call is deprecated.
