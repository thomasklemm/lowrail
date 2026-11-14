| piece | home | up | index | show | new | update |
|---|---:|---:|---:|---:|---:|---:|
| ms per request | 1.37 | 0.7218 | 5.2026 | 2.9355 | 4.6684 | 3.1166 |
| Action View | 8.32 | 4.05 | 24.26 | 13.64 | 56.02 | 0.9 |
| Active Record | 1.14 | 1.55 | 23.23 | 21.33 | 4.17 | 22.63 |
| GC | 6.08 | 6.4 | 8.61 | 5.34 | 8.65 | 11.59 |
| Puma (parse, write, keep-alive) | 14.83 | 26.88 | 4.44 | 8.09 | 5.37 | 7.5 |
| Rack::BodyProxy#close (executor complete, logger finish) | 0.23 | 0.78 | 0.08 | 0.15 | 0.16 | 0.13 |
| Turbo frame layout lambda and etag | 0.44 | 0.0 | 0.1 | 0.27 | 0.12 | 0.0 |
| allow_browser | 7.62 | 0.0 | 2.06 | 4.06 | 2.19 | 3.48 |
| callback chains | 4.09 | 5.21 | 1.31 | 2.32 | 1.73 | 3.08 |
| controller (Metal, AbstractController) | 9.87 | 20.62 | 3.94 | 7.6 | 4.88 | 9.13 |
| csp_meta_tag | 0.06 | 0.0 | 0.03 | 0.05 | 0.03 | 0.0 |
| csrf callbacks | 0.76 | 1.33 | 0.25 | 0.4 | 0.38 | 0.82 |
| csrf_meta_tags | 0.88 | 0.0 | 0.55 | 0.11 | 0.13 | 0.0 |
| flash | 0.06 | 0.11 | 0.21 | 0.4 | 0.03 | 1.07 |
| javascript_importmap_tags | 6.86 | 0.0 | 1.44 | 2.79 | 1.69 | 0.0 |
| logging (loggers, log subscribers, structured events) | 14.77 | 6.98 | 4.3 | 8.11 | 5.65 | 10.38 |
| mw ActionDispatch::Callbacks | 0.03 | 0.0 | 0.0 | 0.0 | 0.01 | 0.01 |
| mw ActionDispatch::ContentSecurityPolicy::Middleware | 0.2 | 0.22 | 0.03 | 0.08 | 0.07 | 0.06 |
| mw ActionDispatch::Cookies | 0.12 | 0.11 | 0.2 | 0.37 | 0.12 | 0.44 |
| mw ActionDispatch::DebugExceptions | 0.26 | 0.39 | 0.02 | 0.01 | 0.1 | 0.03 |
| mw ActionDispatch::Executor | 0.38 | 0.22 | 0.14 | 0.3 | 0.18 | 0.1 |
| mw ActionDispatch::RemoteIp | 0.03 | 0.06 | 0.02 | 0.03 | 0.01 | 0.01 |
| mw ActionDispatch::RequestId | 0.64 | 1.77 | 0.21 | 0.38 | 0.3 | 0.27 |
| mw ActionDispatch::Session::CookieStore | 0.15 | 0.0 | 0.02 | 0.04 | 0.02 | 0.03 |
| mw ActionDispatch::ShowExceptions | 0.0 | 0.0 | 0.01 | 0.0 | 0.0 | 0.01 |
| mw ActionDispatch::Static | 3.88 | 8.65 | 1.39 | 1.19 | 0.96 | 0.03 |
| mw ActiveSupport::Cache::Strategy::LocalCache::Middleware | 0.26 | 0.11 | 0.08 | 0.11 | 0.06 | 0.14 |
| mw Rack::ConditionalGet | 0.12 | 0.06 | 0.03 | 0.04 | 0.03 | 0.01 |
| mw Rack::ETag | 2.28 | 1.94 | 7.47 | 2.18 | 1.21 | 0.05 |
| mw Rack::Head | 0.06 | 0.0 | 0.0 | 0.01 | 0.05 | 0.04 |
| mw Rack::MethodOverride | 0.03 | 0.06 | 0.01 | 0.03 | 0.0 | 0.0 |
| mw Rack::Runtime | 0.44 | 1.39 | 0.16 | 0.1 | 0.21 | 0.31 |
| mw Rack::TempfileReaper | 0.32 | 0.11 | 0.08 | 0.15 | 0.08 | 0.12 |
| mw Rails::Rack::Logger | 0.61 | 1.27 | 0.16 | 0.23 | 0.19 | 0.31 |
| mw Rails::Rack::SilenceRequest | 0.0 | 0.28 | 0.0 | 0.04 | 0.02 | 0.04 |
| notifications machinery | 2.98 | 2.77 | 1.45 | 2.06 | 0.82 | 1.77 |
| params | 2.16 | 3.27 | 0.82 | 1.29 | 0.96 | 12.27 |
| routing | 0.55 | 1.0 | 4.81 | 1.85 | 0.69 | 2.16 |
| session and cookies | 0.73 | 0.89 | 6.03 | 11.13 | 0.22 | 10.97 |
| stylesheet_link_tag | 7.33 | 0.0 | 1.91 | 3.58 | 2.32 | 0.0 |
| turbo_tracking_request_id (own) | 0.44 | 1.55 | 0.15 | 0.14 | 0.16 | 0.13 |
