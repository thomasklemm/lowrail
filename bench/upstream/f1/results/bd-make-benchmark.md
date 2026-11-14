compare-ruby: ruby 4.1.0dev (2026-11-14T18:00:28Z HEAD 88ea6fd282) +PRISM [x86_64-linux]
built-ruby: ruby 4.1.0dev (2026-11-14T19:17:28Z thomasklemm/ar-small-lookup 696e3f5f0c) +PRISM [x86_64-linux]
warming up......
# Iteration per second (i/s)

|            |compare-ruby|built-ruby|
|:-----------|-----------:|---------:|
|miss_empty  |     14.856M|   14.833M|
|            |       1.00x|         -|
|hit_first   |      8.108M|   10.657M|
|            |           -|     1.31x|
|hit_third   |      7.930M|   10.648M|
|            |           -|     1.34x|
|hit_fourth  |      7.942M|   10.695M|
|            |           -|     1.35x|
|hit_last    |      8.028M|   10.733M|
|            |           -|     1.34x|
|miss        |      9.338M|    9.952M|
|            |           -|     1.07x|
