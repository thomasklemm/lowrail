# lowrail-profile compare

Base: `bin/rails test -v`. Head: `bin/rails test -v`.

Objects per request (all, by run): base 25019.9 / 25719.9, head 25656.7 / 25692.1.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request.

## Regressions: 3

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request line | `RAILS/activerecord/lib/active_record/core.rb:433` | 3.58 | 9.13 | +5.55 | 1.61 |
| request line | `RAILS/activerecord/lib/active_record/relation.rb:1507` | 0.16 | 1.22 | +1.06 | 1.0 |
| request line | `RAILS/activerecord/lib/active_record/relation.rb:1520` | 0.16 | 1.22 | +1.06 | 1.0 |

## Improvements: 53

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request line | `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:25` | 283.12 | 0.16 | -282.95 | 1.0 |
| request line | `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:134` | 241.04 | 0.19 | -240.85 | 1.0 |
| request line | `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:147` | 219.84 | 0.14 | -219.70 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:270` | 160.96 | 0.13 | -160.83 | 1.0 |
| request line | `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:91` | 89.91 | 0.1 | -89.81 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/node.rb:145` | 80.48 | 0.07 | -80.41 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/node_set.rb:90` | 80.48 | 0.07 | -80.41 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:264` | 80.48 | 0.07 | -80.41 | 1.0 |
| request line | `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:61` | 45.24 | 0.02 | -45.22 | 1.0 |
| request line | `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:29` | 35.11 | 0.05 | -35.06 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/document_fragment.rb:116` | 24.44 | 0.14 | -24.30 | 1.0 |
| request line | `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:41` | 11.71 | 0.02 | -11.69 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/document_fragment.rb:175` | 8.64 | 0.13 | -8.51 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/css/xpath_visitor.rb:94` | 8.64 | 0.13 | -8.51 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/css/selector_cache.rb:33` | 8.64 | 0.13 | -8.51 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:238` | 8.64 | 0.13 | -8.51 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/document_fragment.rb:44` | 5.75 | 0.33 | -5.42 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/html5/document_fragment.rb:155` | 5.75 | 0.33 | -5.42 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/document_fragment.rb:43` | 5.75 | 0.33 | -5.42 | 1.0 |
| request line | `RAILS/activerecord/lib/active_record/sanitization.rb:208` | 5.6 | 0.27 | -5.33 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/html5/document_fragment.rb:166` | 4.72 | 0.41 | -4.31 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:237` | 4.35 | 0.07 | -4.28 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:245` | 4.32 | 0.07 | -4.25 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:233` | 4.32 | 0.07 | -4.25 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:225` | 4.32 | 0.07 | -4.25 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:223` | 4.32 | 0.07 | -4.25 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:221` | 4.32 | 0.07 | -4.25 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:216` | 4.32 | 0.07 | -4.25 | 1.0 |
| request line | `GEM/nokogiri/lib/nokogiri/xml/node_set.rb:89` | 4.32 | 0.07 | -4.25 | 1.0 |
| request line | `RAILS/actiontext/lib/action_text/fragment.rb:38` | 4.32 | 0.12 | -4.20 | 1.0 |

23 more in the JSON.

Not compared: 32 actions (32 no warm value).
