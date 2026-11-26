# lowrail-profile compare

Base: `bin/rails test -v`. Head: `bin/rails test -v`.

Objects per request (all, by run): base 25019.9 / 25719.9, head 25126.1 / 26461.6.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request.

## Regressions: 1

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request line | `RAILS/activerecord/lib/active_record/core.rb:433` | 3.58 | 8.45 | +4.87 | 2.59 |

## Improvements: 52

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request line | `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:25` | 283.12 | 0.18 | -282.94 | 1.0 |
| request line | `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:134` | 241.04 | 0.18 | -240.86 | 1.0 |
| request line | `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:147` | 219.84 | 0.14 | -219.70 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:270` | 160.96 | 0.16 | -160.80 | 1.0 |
| request line | `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:91` | 89.91 | 0.1 | -89.81 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/node.rb:145` | 80.48 | 0.08 | -80.40 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/node_set.rb:90` | 80.48 | 0.08 | -80.40 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:264` | 80.48 | 0.08 | -80.40 | 1.0 |
| request line | `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:61` | 45.24 | 0.02 | -45.22 | 1.0 |
| request line | `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:29` | 35.11 | 0.04 | -35.07 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/document_fragment.rb:116` | 24.44 | 0.1 | -24.34 | 1.0 |
| request line | `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:41` | 11.71 | 0.02 | -11.69 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:238` | 8.64 | 0.16 | -8.48 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/css/selector_cache.rb:33` | 8.64 | 0.16 | -8.48 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/css/xpath_visitor.rb:94` | 8.64 | 0.16 | -8.48 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/document_fragment.rb:175` | 8.64 | 0.16 | -8.48 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/document_fragment.rb:44` | 5.75 | 0.28 | -5.48 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/html5/document_fragment.rb:155` | 5.75 | 0.28 | -5.48 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/document_fragment.rb:43` | 5.75 | 0.28 | -5.48 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/html5/document_fragment.rb:166` | 4.72 | 0.36 | -4.36 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:237` | 4.35 | 0.08 | -4.27 | 1.0 |
| request line | `RAILS/actiontext/lib/action_text/html_conversion.rb:23` | 4.32 | 0.08 | -4.24 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/document.rb:208` | 4.32 | 0.08 | -4.24 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/document.rb:209` | 4.32 | 0.08 | -4.24 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/document_fragment.rb:174` | 4.32 | 0.08 | -4.24 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/node_set.rb:22` | 4.32 | 0.08 | -4.24 | 1.0 |
| request line | `RAILS/actiontext/lib/action_text/fragment.rb:38` | 4.32 | 0.08 | -4.24 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/node_set.rb:89` | 4.32 | 0.08 | -4.24 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:216` | 4.32 | 0.08 | -4.24 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:221` | 4.32 | 0.08 | -4.24 | 1.0 |

22 more in the JSON.

Not compared: 32 actions (1 no warm value in the A/A report, 31 no warm value).
