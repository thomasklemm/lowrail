| per iteration (railsbench / lobsters / shipit) | master ZJIT | headline ZJIT | master YJIT |
| --- | ---: | ---: | ---: |
| sends | 13055k / 7278k / 13978k | 13074k / 7258k / 13757k | – |
| dynamic sends | 575k / 622k / 1427k | 171k / 125k / 327k | 389k / 334k / 659k |
| side exits | 4.0k / 8.1k / 7.0k | 13 / 1.2k / 3 | 9.0k / 3.1k / 7.0k |
| generic ivar reads | 201k / 423k / 1019k | 244k / 275k / 579k | – |
| generic ivar writes | 2.0k / 11k / 42k | 2.2k / 16k / 61k | – |
| throws | 4.0k / 5.4k / 5.3k | 2.0k / 236 / 2.9k | – |

| reason (per iteration, railsbench / lobsters / shipit) | master ZJIT | headline ZJIT |
| --- | ---: | ---: |
| `getivar_fallback_no_profile_missing_ic` | 170k / 233k / 658k | 0 / 0 / 0 |
| `send_fallback_send_polymorphic_fallback` | 24k / 263k / 705k | 376 / 26k / 59k |
| `getivar_fallback_no_side_exits` | 31k / 188k / 359k | 41k / 82k / 116k |
| `send_fallback_send_megamorphic` | 78k / 123k / 147k | 12k / 13k / 2.9k |
| `send_fallback_send_block_arg_not_nil` | 115k / 51k / 147k | 0 / 75 / 31k |
| `send_fallback_one_or_more_complex_arg_pass` | 83k / 37k / 67k | 26 / 10k / 14k |
| `send_fallback_sendforward_not_specialized` | 46k / 27k / 103k | 0 / 0 / 0 |
| `send_fallback_invokeblock_not_specialized` | 54k / 51k / 52k | 45k / 22k / 46k |
| `send_fallback_send_not_optimized_method_type_optimized` | 40k / 26k / 68k | 2.0k / 1.6k / 5.1k |
| `unspecialized_send_def_type_optimized_send` | 40k / 26k / 68k | 2.0k / 1.4k / 4.7k |
| `send_fallback_send_not_optimized_need_permission` | 47k / 16k / 36k | 0 / 0 / 0 |
| `send_fallback_invokeblock_polymorphic_miss` | 2.0k / 9.5k / 51k | 2.0k / 2.2k / 8.4k |
| `send_fallback_send_not_optimized_method_type` | 37k / 5.7k / 9.0k | 39k / 8.5k / 13k |
| `setivar_fallback_no_side_exits` | 0 / 6.5k / 39k | 0 / 670 / 66 |
| `unspecialized_send_def_type_optimized` | 29k / 1.4k / 2.2k | 29k / 2.9k / 2.2k |
| `send_fallback_invokesuperforward_not_specialized` | 20k / 2.5k / 6.7k | 20k / 2.5k / 6.7k |
| `complex_arg_pass_param_kwrest` | 2.0k / 4.3k / 21k | 0 / 0 / 0 |
| `send_fallback_super_call_with_block` | 4.0k / 1.3k / 21k | 4.0k / 1.3k / 21k |
| `send_fallback_super_complex_args_pass` | 17k / 2.4k / 6.6k | 17k / 2.3k / 4.1k |
| `unspecialized_send_def_type_null` | 7.3k / 4.3k / 6.8k | 9.3k / 4.3k / 6.9k |
| `caller_splat_profile_monomorphic` | 13k / 1.5k / 2.3k | 15k / 2.1k / 2.9k |
| `caller_splat_optimized` | 11k / 1.5k / 3.9k | 17k / 1.7k / 10k |
| `exit_exception_handler` | 4.0k / 5.4k / 6.7k | 0 / 0 / 0 |
| `complex_arg_pass_caller_kw_splat` | 2.0k / 3.0k / 5.1k | 0 / 3.5k / 7.5k |
| `send_fallback_super_from_block` | 6.0k / 1.4k / 2.7k | 6.0k / 1.4k / 2.7k |
| `complex_arg_pass_caller_blockarg` | 2.0k / 5.5k / 277 | 0 / 6.4k / 3.3k |
| `send_fallback_super_polymorphic` | 26 / 1.3k / 3.0k | 13 / 1.4k / 7.6k |
| `send_fallback_send_polymorphic` | 0 / 1.2k / 86 | 7.9k / 5.2k / 6.1k |
| `send_fallback_send_no_profiles` | 0 / 226 / 20 | 103 / 4.5k / 1.7k |
| `getivar_fallback_shape_chain_miss` | 0 / 0 / 0 | 168k / 166k / 400k |
| `getivar_fallback_shape_miss` | 0 / 0 / 0 | 29k / 23k / 55k |
| `getivar_fallback_no_profile` | 0 / 0 / 0 | 6.6k / 3.2k / 6.5k |
| `send_fallback_sendforward_polymorphic_call_info` | 0 / 0 / 0 | 4.0k / 10k / 52k |
| `send_fallback_sendforward_complex_args` | 0 / 0 / 0 | 6.0k / 962 / 4.3k |
| `send_fallback_send_name_miss` | 0 / 0 / 0 | 0 / 4.9k / 17k |
| `setivar_fallback_shape_chain_miss` | 0 / 0 / 0 | 175 / 11k / 58k |
| `send_fallback_send_method_entry_miss` | 0 / 0 / 0 | 4.0k / 5.0k / 23k |

| C method called with a frame (per iteration) | master ZJIT | headline ZJIT |
| --- | ---: | ---: |
| `Hash#fetch` | 54k / 81k / 302k | 94k / 83k / 303k |
| `Hash#key?` | 122k / 29k / 48k | 122k / 30k / 48k |
| `Array#fetch` | 27k / 61k / 74k | 27k / 61k / 74k |
| `Array#any?` | 62k / 23k / 53k | 62k / 23k / 53k |
| `Integer#==` | 21k / 18k / 78k | 21k / 16k / 78k |
| `ObjectSpace::WeakKeyMap#[]` | 20k / 7.3k / 58k | 20k / 7.3k / 58k |
| `Hash#delete` | 44k / 19k / 16k | 44k / 19k / 16k |
| `Hash#[]` | 60k / 11k / 9.7k | 60k / 11k / 5.6k |
| `Array#include?` | 19k / 19k / 28k | 19k / 21k / 28k |
| `Regexp#match?` | 24k / 26k / 16k | 24k / 26k / 16k |
| `Process.clock_gettime` | 34k / 6.9k / 22k | 34k / 6.9k / 22k |
| `String#match?` | 33k / 22k / 5.2k | 33k / 22k / 5.2k |
| `Kernel#dup` | 20k / 9.9k / 29k | 20k / 10k / 29k |
| `String.new` | 36k / 11k / 11k | 36k / 11k / 11k |
| `Array#reverse_each` | 9.9k / 6.9k / 34k | 9.9k / 6.9k / 34k |
| `Hash#[]=` | 40k / 2.6k / 1.4k | 40k / 2.6k / 1.4k |
