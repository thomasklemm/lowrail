| per operation | Campfire | Writebook |
| --- | ---: | ---: |
| ZJIT sends, master | 66483 | 190216 |
| ZJIT dynamic sends, master | 6168 | 19182 |
| ZJIT dynamic sends, headline | 1651 | 3726 |
| YJIT dynamic sends | 2899 | 9288 |
| ZJIT side exits, master | 48 | 56 |
| ZJIT side exits, headline | 37 | 13 |
| YJIT side exits | 38 | 84 |
| ZJIT generic ivar reads, master | 3678 | 12362 |
| ZJIT generic ivar reads, headline | 2595 | 10288 |

campfire, top reasons per operation: master: send_polymorphic_fallback 2393, getivar_fallback_no_profile_missing_ic 2130, getivar_fallback_no_side_exits 1502, send_megamorphic 1289, send_block_arg_not_nil 491, singleton_class_seen 337, sendforward_not_specialized 300, invokeblock_not_specialized 284, one_or_more_complex_arg_pass 273, invokeblock_polymorphic_miss 208.
headline: getivar_fallback_shape_chain_miss 1467, getivar_fallback_no_side_exits 692, getivar_fallback_shape_miss 426, setivar_fallback_shape_chain_miss 379, singleton_class_seen 271, invokeblock_not_specialized 178, send_polymorphic_fallback 167, send_method_entry_miss 165, send_megamorphic 141, sendforward_polymorphic_call_info 139.

writebook, top reasons per operation: master: send_polymorphic_fallback 10310, getivar_fallback_no_profile_missing_ic 7875, getivar_fallback_no_side_exits 4460, send_megamorphic 3121, send_block_arg_not_nil 1267, sendforward_not_specialized 826, one_or_more_complex_arg_pass 670, send_not_optimized_method_type_optimized 669, invokeblock_polymorphic_miss 612, invokeblock_not_specialized 542.
headline: getivar_fallback_shape_chain_miss 7262, getivar_fallback_shape_miss 2183, setivar_fallback_shape_chain_miss 1095, send_polymorphic_fallback 993, getivar_fallback_no_side_exits 806, sendforward_polymorphic_call_info 507, invokeblock_not_specialized 378, one_or_more_complex_arg_pass 322, invokeblock_polymorphic_miss 284, super_call_with_block 233.
