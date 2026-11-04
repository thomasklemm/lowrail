### Require minitest 5.18 in Active Support

23420be739 added `alias :assert_not_pattern :refute_pattern` to `ActiveSupport::TestCase`. `refute_pattern` arrived in minitest 5.18, but Active Support still declares `minitest >= 5.1`. Bundler can therefore pick an older minitest, and then `require "active_support/test_case"` raises:

```
active_support/test_case.rb:372:in '<class:TestCase>': undefined method 'refute_pattern' for class 'ActiveSupport::TestCase' (NameError)
```

active_model_serializers pins `minitest < 5.11` for development, and its suite stops there.

| `require "active_support/test_case"` | minitest 5.10.3 | minitest 5.18.0 |
|---|---|---|
| 8-1-stable | loads | loads |
| main | NameError | loads |
| main without the alias | loads | loads |

The unconditional alias requires minitest 5.18 or newer, so this declares `>= 5.18`, as 07ac43aaef did for ractor-dispatch. Bundler then reports the conflict ("every version of activesupport depends on minitest >= 5.18") instead of resolving a minitest that cannot load. The alternative, an alias guarded by `method_defined?`, would keep supporting releases older than the API Active Support now uses. minitest 5.18 is from March 2023, and Rails' own lockfile is on minitest 6.

---

<sub>Found by running the test suites of widely used gems on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md), part of my research project Lowrail).</sub>
