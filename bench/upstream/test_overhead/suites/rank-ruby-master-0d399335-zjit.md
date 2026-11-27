| Part | campfire | writebook | fizzy | codetriage | hackatime | casa | sure | loomio | mastodon | Median |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| tests | 634 | 310 | 1787 | 219 | 794 | 2992 | 14236 | 3660 | 7748 | |
| cpu ms per test | 47.6 | 162.4 | 46.8 | 24.5 | 40.1 | 44.1 | 50.7 | 102.6 | 73.7 | |
| objects per test | 38826 | 28653 | 27479 | 8445 | 15141 | 21260 | 24691 | 52330 | 39667 | |
| SQL and event debug logging | 4.9% | 6.5% | 9.6% | 8.6% | 7.3% | 8.3% | 13.3% | 0.3% | 34.5% | 8.3% |
| · of which query source (verbose_query_logs) | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 29.3% | 0.0% |
| Fixtures, all | 4.6% | 3.3% | 5.2% | 10.2% | 1.8% | 1.7% | 3.2% | 1.9% | 2.1% | 3.2% |
| · fixture loading | 1.3% | 0.6% | 1.6% | 2.1% | 0.0% | 0.0% | 0.3% | 0.3% | 0.0% | 0.3% |
| · transactional setup and teardown | 1.2% | 1.2% | 0.8% | 4.6% | 1.5% | 1.4% | 1.0% | 0.3% | 2.0% | 1.2% |
| · fixture accessors (record finds) | 1.6% | 1.4% | 2.6% | 3.0% | 0.0% | 0.0% | 1.7% | 1.1% | 0.0% | 1.4% |
| Integration session, outside the request | 1.8% | 1.9% | 1.5% | 0.1% | 1.3% | 0.5% | 0.7% | 0.0% | 0.2% | 0.7% |
| · rack-test request and cookies | 1.1% | 1.3% | 1.2% | 0.1% | 0.9% | 0.3% | 0.6% | 0.0% | 0.1% | 0.6% |
| Controller test plumbing, outside the action | 0.0% | 0.0% | 0.0% | 0.3% | 0.0% | 0.1% | 0.0% | 0.3% | 0.1% | 0.0% |
| Factories, all (factory_bot, Fabrication) | 0.0% | 0.0% | 0.0% | 0.0% | 30.9% | 42.6% | 0.0% | 0.0% | 57.0% | 0.0% |
| · factory gem's own code | 0.0% | 0.0% | 0.0% | 0.0% | 1.5% | 2.5% | 0.0% | 0.0% | 0.6% | 0.0% |
| Test framework (Minitest, RSpec, Rails test helpers), own code | 1.9% | 1.9% | 1.4% | 1.8% | 1.7% | 2.6% | 0.7% | 0.5% | 1.5% | 1.7% |
| Mocks and stubs (Mocha, WebMock, rspec-mocks) | 1.2% | 0.0% | 0.5% | 3.6% | 0.8% | 1.3% | 0.6% | 0.2% | 1.2% | 0.8% |
| Garbage collection | 7.0% | 6.3% | 7.5% | 8.0% | 8.4% | 9.3% | 7.6% | 5.4% | 10.9% | 7.6% |
