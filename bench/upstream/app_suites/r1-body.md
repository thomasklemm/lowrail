### Restore RemoteIp::GetIp#filter_proxies as deprecated

#56805 made computing the remote IP noticeably cheaper by replacing `filter_proxies` with `first_non_proxy`, which stops at the first IP that isn't a trusted proxy. Thanks for that. On 8-1, `filter_proxies` was private but marked `# :doc:`, so it appeared in the API docs, and at least one known extension still calls it.

That extension is Mastodon. Its `lib/action_dispatch/remote_ip_extensions.rb` prepends its own `calculate_ip` to `GetIp` and calls `filter_proxies([remote_addr] + ips).first`. On main, calls that reach `filter_proxies` raise `NoMethodError`, and most of Mastodon's request specs fail that way.

As a small compatibility bridge, this adds `filter_proxies(ips)` back as a private `:doc:` method with 8-1's body. It returns every IP that isn't a trusted proxy, in order. It warns through `ActionDispatch.deprecator` that it will be removed in Rails 9.0, and suggests replacing `filter_proxies(ips).first` with `first_non_proxy(ips)`. The optimized `calculate_ip` path is unchanged and doesn't call it.

The test checks that IPv4, IPv6 and Regexp proxies give the same results as 8-1-stable, and that each call warns.
