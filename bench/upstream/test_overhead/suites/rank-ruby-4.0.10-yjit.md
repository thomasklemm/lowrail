| Part | campfire | writebook | fizzy | codetriage | hackatime | casa | sure | loomio | mastodon | Median |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| tests | 634 | 310 | 1787 | 219 | 794 | 2992 | 14236 | 3660 | 7748 | |
| cpu ms per test | 41.6 | 156.2 | 40.8 | 19.6 | 35.2 | 32.9 | 46.2 | 86.4 | 62.1 | |
| objects per test | 39334 | 29639 | 28578 | 8473 | 15164 | 21454 | 25293 | 53375 | 39738 | |
| SQL and event debug logging | 5.4% | 7.0% | 10.1% | 9.1% | 7.0% | 8.5% | 14.2% | 0.2% | 39.1% | 8.5% |
| · of which query source (verbose_query_logs) | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 34.0% | 0.0% |
| Fixtures, all | 4.1% | 2.9% | 5.4% | 9.1% | 1.5% | 1.6% | 3.3% | 1.9% | 2.2% | 2.9% |
| · fixture loading | 1.2% | 0.5% | 1.6% | 2.1% | 0.0% | 0.0% | 0.2% | 0.4% | 0.0% | 0.4% |
| · transactional setup and teardown | 0.9% | 1.0% | 1.0% | 3.6% | 1.3% | 1.5% | 1.1% | 0.3% | 2.1% | 1.1% |
| · fixture accessors (record finds) | 1.5% | 1.3% | 2.6% | 3.0% | 0.0% | 0.0% | 1.8% | 1.1% | 0.0% | 1.3% |
| Integration session, outside the request | 1.6% | 1.6% | 1.3% | 0.1% | 1.4% | 0.5% | 0.8% | 0.1% | 0.2% | 0.8% |
| · rack-test request and cookies | 1.1% | 1.2% | 1.1% | 0.0% | 1.1% | 0.3% | 0.6% | 0.0% | 0.1% | 0.6% |
| Controller test plumbing, outside the action | 0.0% | 0.0% | 0.0% | 0.4% | 0.0% | 0.0% | 0.0% | 0.3% | 0.1% | 0.0% |
| Factories, all (factory_bot, Fabrication) | 0.0% | 0.0% | 0.0% | 0.0% | 26.0% | 43.7% | 0.0% | 0.0% | 56.7% | 0.0% |
| · factory gem's own code | 0.0% | 0.0% | 0.0% | 0.0% | 1.4% | 3.9% | 0.0% | 0.0% | 0.5% | 0.0% |
| Test framework (Minitest, RSpec, Rails test helpers), own code | 1.5% | 1.7% | 1.4% | 1.8% | 1.8% | 2.5% | 0.8% | 0.6% | 1.5% | 1.5% |
| Mocks and stubs (Mocha, WebMock, rspec-mocks) | 1.1% | 0.0% | 0.3% | 3.4% | 0.6% | 1.0% | 0.6% | 0.2% | 1.1% | 0.6% |
| Garbage collection | 11.3% | 10.7% | 10.6% | 9.1% | 10.3% | 10.2% | 5.9% | 5.7% | 10.6% | 10.3% |
