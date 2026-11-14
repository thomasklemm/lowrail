| piece | home | show |
|---|---:|---:|
| ms per request | 0.667 | 1.4347 |
| Action View | 0.87 | 1.17 |
| Active Record | 1.41 | 38.17 |
| GC | 5.99 | 12.22 |
| Puma (parse, write, keep-alive) | 23.99 | 10.82 |
| Rack::BodyProxy#close (executor complete, logger finish) | 0.6 | 0.2 |
| callback chains | 1.35 | 1.48 |
| controller (Metal, AbstractController) | 11.75 | 11.88 |
| logging (loggers, log subscribers, structured events) | 22.37 | 12.31 |
| mw ActionDispatch::Callbacks | 0.0 | 0.01 |
| mw ActionDispatch::DebugExceptions | 0.0 | 0.04 |
| mw ActionDispatch::Executor | 0.45 | 0.24 |
| mw ActionDispatch::RemoteIp | 0.18 | 0.0 |
| mw ActionDispatch::RequestId | 1.41 | 0.78 |
| mw ActionDispatch::ShowExceptions | 0.03 | 0.0 |
| mw ActionDispatch::Static | 16.28 | 2.1 |
| mw ActiveSupport::Cache::Strategy::LocalCache::Middleware | 0.39 | 0.17 |
| mw Rack::ConditionalGet | 0.06 | 0.08 |
| mw Rack::ETag | 1.17 | 1.38 |
| mw Rack::Head | 0.09 | 0.06 |
| mw Rack::Runtime | 0.3 | 0.15 |
| mw Rails::Rack::Logger | 0.78 | 0.32 |
| mw Rails::Rack::SilenceRequest | 0.03 | 0.0 |
| notifications machinery | 6.0 | 3.22 |
| params | 3.57 | 1.76 |
| routing | 0.93 | 1.45 |
