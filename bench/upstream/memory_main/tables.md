## Levels (mean of two runs ± their difference)

### RssAnon after boot and eager load, MB

| app | r4010-interpreter r81 | r4010-interpreter main | r4010-zjit r81 | r4010-zjit main | master-interpreter r81 | master-interpreter main | master-zjit r81 | master-zjit main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | 109.9 ±1.5 | 112.6 ±0.2 | 124.9 ±0.1 | 129.6 ±0.1 | 99.3 ±0.4 | 102.6 ±0.3 | 109.0 ±0.0 | 112.7 ±0.2 |
| writebook | 129.4 ±7.1 | 136.4 ±0.1 | 150.4 ±0.0 | 153.8 ±0.0 | 119.9 ±1.9 | 122.1 ±2.3 | 126.9 ±0.0 | 131.0 ±0.1 |
| pingcrm | 128.5 ±27.0 | 122.2 ±8.6 | 135.1 ±0.3 | 136.8 ±2.3 | 108.8 ±11.1 | 106.0 ±2.5 | 112.6 ±0.1 | 116.8 ±1.1 |
| redprints-cfp | 151.9 ±33.4 | 146.6 ±0.5 | 194.2 ±67.8 | 181.2 ±29.2 | 132.4 ±16.6 | 129.1 ±2.7 | 147.3 ±18.8 | 147.2 ±10.0 |
| react-starter-kit | 109.5 ±5.8 | 111.7 ±6.2 | 120.4 ±1.0 | 125.8 ±1.8 | 100.5 ±11.3 | 97.8 ±0.9 | 104.0 ±0.0 | 107.5 ±0.2 |
| sure | 390.6 ±6.0 | 382.8 ±0.4 | 454.0 ±7.1 | 468.6 ±0.7 | 338.9 ±0.6 | 329.3 ±2.7 | 354.9 ±0.4 | 341.9 ±24.4 |

### GC heap (count_objects_size TOTAL) after boot, MB

| app | r4010-interpreter r81 | r4010-interpreter main | r4010-zjit r81 | r4010-zjit main | master-interpreter r81 | master-interpreter main | master-zjit r81 | master-zjit main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | 72.9 ±0.1 | 75.9 ±0.1 | 72.9 ±0.0 | 75.7 ±0.0 | 68.3 ±0.1 | 70.8 ±0.1 | 69.2 ±0.2 | 71.7 ±0.0 |
| writebook | 89.2 ±0.0 | 91.7 ±0.0 | 89.5 ±0.0 | 91.8 ±0.0 | 84.0 ±0.0 | 86.1 ±0.0 | 84.8 ±0.0 | 86.9 ±0.0 |
| pingcrm | 77.5 ±0.6 | 79.8 ±0.1 | 77.4 ±0.0 | 79.6 ±0.0 | 71.4 ±0.1 | 73.5 ±0.0 | 72.3 ±0.0 | 74.3 ±0.0 |
| redprints-cfp | 98.7 ±0.6 | 102.2 ±0.1 | 98.5 ±0.1 | 102.1 ±0.0 | 91.3 ±0.1 | 94.5 ±0.1 | 92.2 ±0.1 | 95.5 ±0.0 |
| react-starter-kit | 72.2 ±0.6 | 75.4 ±0.1 | 72.0 ±0.0 | 75.2 ±0.0 | 66.6 ±0.0 | 69.4 ±0.1 | 67.4 ±0.0 | 70.2 ±0.0 |
| sure | 255.4 ±0.0 | 258.1 ±0.0 | 255.2 ±0.1 | 257.8 ±0.0 | 231.7 ±0.0 | 233.8 ±0.1 | 232.9 ±0.1 | 235.1 ±0.2 |

### RssAnon after 1,000 requests, MB

| app | r4010-interpreter r81 | r4010-interpreter main | r4010-zjit r81 | r4010-zjit main | master-interpreter r81 | master-interpreter main | master-zjit r81 | master-zjit main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | 114.2 ±0.2 | 115.6 ±0.8 | 149.1 ±0.7 | 157.8 ±0.6 | 103.3 ±2.8 | 106.3 ±0.3 | 137.5 ±0.4 | 142.2 ±0.3 |
| writebook | 140.4 ±4.8 | 143.7 ±0.1 | 178.2 ±0.6 | 181.5 ±0.7 | 129.6 ±3.9 | 133.7 ±4.2 | 164.5 ±0.2 | 173.0 ±0.3 |
| pingcrm | 129.8 ±26.3 | 122.7 ±8.1 | 152.4 ±0.3 | 157.5 ±0.6 | 112.2 ±9.7 | 111.9 ±2.9 | 134.8 ±1.3 | 141.4 ±1.1 |
| redprints-cfp | 153.8 ±31.7 | 157.0 ±12.0 | 220.8 ±50.8 | 213.4 ±4.9 | 138.1 ±12.1 | 133.3 ±5.5 | 166.7 ±10.5 | 168.8 ±4.1 |
| react-starter-kit | 117.7 ±17.5 | 120.9 ±21.1 | 139.0 ±1.3 | 146.0 ±1.1 | 102.2 ±12.0 | 99.5 ±0.6 | 118.8 ±0.0 | 126.2 ±0.9 |
| sure | 468.5 ±36.5 | 461.7 ±28.5 | 552.9 ±11.2 | 560.7 ±1.3 | 378.8 ±20.6 | 387.2 ±1.7 | 456.9 ±16.4 | 449.5 ±21.8 |

### GC heap after 1,000 requests, MB

| app | r4010-interpreter r81 | r4010-interpreter main | r4010-zjit r81 | r4010-zjit main | master-interpreter r81 | master-interpreter main | master-zjit r81 | master-zjit main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | 75.6 ±0.2 | 78.2 ±0.1 | 75.9 ±0.1 | 78.3 ±0.0 | 72.9 ±0.1 | 75.0 ±0.1 | 73.7 ±0.2 | 76.0 ±0.0 |
| writebook | 93.4 ±0.0 | 95.9 ±0.0 | 94.8 ±0.0 | 96.9 ±0.0 | 88.0 ±0.0 | 90.1 ±0.0 | 88.8 ±0.0 | 90.9 ±0.0 |
| pingcrm | 80.0 ±0.6 | 82.4 ±0.1 | 79.8 ±0.0 | 82.2 ±0.0 | 73.8 ±0.1 | 75.9 ±0.0 | 74.6 ±0.0 | 76.7 ±0.0 |
| redprints-cfp | 100.8 ±0.6 | 104.5 ±0.1 | 101.5 ±0.9 | 104.7 ±0.0 | 93.3 ±0.0 | 96.7 ±0.1 | 94.3 ±0.1 | 97.7 ±0.0 |
| react-starter-kit | 74.3 ±0.5 | 77.4 ±0.1 | 74.3 ±0.0 | 77.3 ±0.0 | 68.6 ±0.0 | 71.3 ±0.1 | 69.3 ±0.0 | 72.0 ±0.0 |
| sure | 269.0 ±0.2 | 271.8 ±0.0 | 292.1 ±0.5 | 291.9 ±0.0 | 245.6 ±0.2 | 247.8 ±0.1 | 246.8 ±0.0 | 249.1 ±0.1 |

### RssAnon growth per request, requests 1,000 to 5,000, bytes

| app | r4010-interpreter r81 | r4010-interpreter main | r4010-zjit r81 | r4010-zjit main | master-interpreter r81 | master-interpreter main | master-zjit r81 | master-zjit main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | 834 ±13 | 607 ±49 | 528 ±99 | 577 ±29 | 1179 ±257 | 1117 ±293 | 1853 ±414 | 1675 ±261 |
| writebook | 1248 ±1156 | 199 ±71 | 1689 ±135 | 1302 ±159 | 1191 ±124 | 1593 ±198 | 1925 ±109 | 1708 ±46 |
| pingcrm | 393 ±294 | 434 ±113 | 246 ±66 | 319 ±16 | 1252 ±1251 | 2432 ±659 | 1964 ±1408 | 170 ±185 |
| redprints-cfp | 342 ±28 | 194 ±223 | 149 ±3 | 206 ±281 | 102 ±204 | 838 ±84 | 152 ±7 | 593 ±1090 |
| react-starter-kit | 2179 ±2101 | 2484 ±2339 | 931 ±7 | 637 ±375 | 1268 ±1778 | 950 ±1406 | 554 ±48 | 2004 ±5 |
| sure | 2009 ±2036 | -1361 ±11521 | 511 ±316 | 541 ±1 | 1961 ±6057 | 1035 ±410 | 1130 ±5830 | 3951 ±42 |

### GC heap growth per request, requests 1,000 to 5,000, bytes

| app | r4010-interpreter r81 | r4010-interpreter main | r4010-zjit r81 | r4010-zjit main | master-interpreter r81 | master-interpreter main | master-zjit r81 | master-zjit main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | -45 ±12 | -40 ±0 | -45 ±12 | -40 ±0 | 41 ±149 | -32 ±1 | -35 ±1 | -33 ±0 |
| writebook | -217 ±0 | -220 ±0 | -217 ±0 | -220 ±0 | 44 ±0 | 41 ±1 | 44 ±0 | 41 ±0 |
| pingcrm | -261 ±0 | -261 ±0 | -261 ±0 | -261 ±0 | 1 ±0 | 0 ±0 | 0 ±0 | 0 ±0 |
| redprints-cfp | -260 ±1 | -261 ±0 | -130 ±261 | 1 ±0 | 1 ±0 | 1 ±0 | 0 ±0 | 1 ±0 |
| react-starter-kit | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 |
| sure | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 | -0 ±0 | -0 ±2 | 0 ±1 |

### Live objects (heap_live_slots) growth per request, requests 1,000 to 5,000

| app | r4010-interpreter r81 | r4010-interpreter main | r4010-zjit r81 | r4010-zjit main | master-interpreter r81 | master-interpreter main | master-zjit r81 | master-zjit main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | -0 ±0 | -0 ±0 | -0 ±0 | -0 ±0 | 1 ±2 | -0 ±0 | -0 ±0 | -0 ±0 |
| writebook | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 |
| pingcrm | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 |
| redprints-cfp | -0 ±0 | -0 ±0 | -0 ±0 | -0 ±0 | -0 ±0 | -0 ±0 | -0 ±0 | -0 ±0 |
| react-starter-kit | -0 ±0 | -0 ±0 | -0 ±0 | -0 ±0 | -0 ±0 | -0 ±0 | -0 ±0 | -0 ±0 |
| sure | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 | 0 ±0 | -0 ±0 | -0 ±0 | 0 ±0 |

### ZJIT total_mem_bytes after boot, MB

| app | r4010-interpreter r81 | r4010-interpreter main | r4010-zjit r81 | r4010-zjit main | master-interpreter r81 | master-interpreter main | master-zjit r81 | master-zjit main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | 0.0 ±0.0 | 0.0 ±0.0 | 16.6 ±0.0 | 17.4 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 9.0 ±0.0 | 9.5 ±0.0 |
| writebook | 0.0 ±0.0 | 0.0 ±0.0 | 15.0 ±0.0 | 15.8 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 9.4 ±0.0 | 10.0 ±0.0 |
| pingcrm | 0.0 ±0.0 | 0.0 ±0.0 | 17.6 ±0.0 | 18.2 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 9.0 ±0.0 | 9.5 ±0.0 |
| redprints-cfp | 0.0 ±0.0 | 0.0 ±0.0 | 49.1 ±46.5 | 36.1 ±18.9 | 0.0 ±0.0 | 0.0 ±0.0 | 14.3 ±0.2 | 15.0 ±0.0 |
| react-starter-kit | 0.0 ±0.0 | 0.0 ±0.0 | 16.4 ±0.0 | 17.3 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 8.7 ±0.0 | 9.4 ±0.0 |
| sure | 0.0 ±0.0 | 0.0 ±0.0 | 75.6 ±15.7 | 84.3 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 21.5 ±0.0 | 22.5 ±0.2 |

### ZJIT total_mem_bytes after 1,000 requests, MB

| app | r4010-interpreter r81 | r4010-interpreter main | r4010-zjit r81 | r4010-zjit main | master-interpreter r81 | master-interpreter main | master-zjit r81 | master-zjit main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | 0.0 ±0.0 | 0.0 ±0.0 | 32.7 ±0.0 | 34.3 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 29.1 ±0.1 | 30.0 ±0.0 |
| writebook | 0.0 ±0.0 | 0.0 ±0.0 | 35.5 ±0.0 | 37.1 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 37.4 ±0.0 | 38.6 ±0.0 |
| pingcrm | 0.0 ±0.0 | 0.0 ±0.0 | 32.6 ±0.0 | 33.5 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 28.4 ±0.0 | 29.0 ±0.0 |
| redprints-cfp | 0.0 ±0.0 | 0.0 ±0.0 | 62.8 ±47.0 | 50.1 ±19.2 | 0.0 ±0.0 | 0.0 ±0.0 | 30.6 ±0.1 | 31.7 ±0.1 |
| react-starter-kit | 0.0 ±0.0 | 0.0 ±0.0 | 28.5 ±0.0 | 29.4 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 22.1 ±0.0 | 22.9 ±0.0 |
| sure | 0.0 ±0.0 | 0.0 ±0.0 | 115.0 ±15.6 | 125.2 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 79.4 ±0.9 | 81.0 ±0.2 |

### ZJIT code_region_bytes after 1,000 requests, MB

| app | r4010-interpreter r81 | r4010-interpreter main | r4010-zjit r81 | r4010-zjit main | master-interpreter r81 | master-interpreter main | master-zjit r81 | master-zjit main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | 0.0 ±0.0 | 0.0 ±0.0 | 6.8 ±0.0 | 7.1 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 9.9 ±0.0 | 10.2 ±0.0 |
| writebook | 0.0 ±0.0 | 0.0 ±0.0 | 8.0 ±0.0 | 8.5 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 13.9 ±0.0 | 14.2 ±0.0 |
| pingcrm | 0.0 ±0.0 | 0.0 ±0.0 | 6.6 ±0.0 | 6.9 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 9.7 ±0.0 | 9.9 ±0.0 |
| redprints-cfp | 0.0 ±0.0 | 0.0 ±0.0 | 7.0 ±0.1 | 7.3 ±0.1 | 0.0 ±0.0 | 0.0 ±0.0 | 10.7 ±0.1 | 11.2 ±0.0 |
| react-starter-kit | 0.0 ±0.0 | 0.0 ±0.0 | 5.4 ±0.0 | 5.6 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 7.7 ±0.0 | 8.0 ±0.0 |
| sure | 0.0 ±0.0 | 0.0 ±0.0 | 16.5 ±0.1 | 17.1 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 30.9 ±0.5 | 31.3 ±0.1 |

### ZJIT zjit_alloc_bytes after 1,000 requests, MB

| app | r4010-interpreter r81 | r4010-interpreter main | r4010-zjit r81 | r4010-zjit main | master-interpreter r81 | master-interpreter main | master-zjit r81 | master-zjit main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | 0.0 ±0.0 | 0.0 ±0.0 | 25.9 ±0.0 | 27.3 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 14.7 ±0.0 | 15.0 ±0.0 |
| writebook | 0.0 ±0.0 | 0.0 ±0.0 | 27.4 ±0.0 | 28.6 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 17.6 ±0.0 | 18.3 ±0.0 |
| pingcrm | 0.0 ±0.0 | 0.0 ±0.0 | 26.0 ±0.0 | 26.6 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 14.2 ±0.0 | 14.5 ±0.0 |
| redprints-cfp | 0.0 ±0.0 | 0.0 ±0.0 | 55.8 ±46.9 | 42.7 ±19.1 | 0.0 ±0.0 | 0.0 ±0.0 | 15.0 ±0.1 | 15.5 ±0.0 |
| react-starter-kit | 0.0 ±0.0 | 0.0 ±0.0 | 23.1 ±0.0 | 23.8 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 10.8 ±0.0 | 11.2 ±0.0 |
| sure | 0.0 ±0.0 | 0.0 ±0.0 | 98.4 ±15.7 | 108.1 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 35.5 ±0.2 | 36.4 ±0.1 |

### ZJIT jit_frame_region_bytes after 1,000 requests, MB (master only)

| app | r4010-interpreter r81 | r4010-interpreter main | r4010-zjit r81 | r4010-zjit main | master-interpreter r81 | master-interpreter main | master-zjit r81 | master-zjit main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 4.5 ±0.0 | 4.7 ±0.0 |
| writebook | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 6.0 ±0.0 | 6.1 ±0.0 |
| pingcrm | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 4.4 ±0.0 | 4.6 ±0.0 |
| redprints-cfp | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 4.8 ±0.0 | 5.0 ±0.0 |
| react-starter-kit | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 3.5 ±0.0 | 3.7 ±0.0 |
| sure | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 13.0 ±0.2 | 13.3 ±0.0 |

### ZJIT side_exit_size_bytes (inside code_region_bytes) after 1,000 requests, MB (master only)

| app | r4010-interpreter r81 | r4010-interpreter main | r4010-zjit r81 | r4010-zjit main | master-interpreter r81 | master-interpreter main | master-zjit r81 | master-zjit main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 3.4 ±0.0 | 3.6 ±0.0 |
| writebook | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 4.4 ±0.0 | 4.5 ±0.0 |
| pingcrm | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 3.3 ±0.0 | 3.4 ±0.0 |
| redprints-cfp | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 3.6 ±0.0 | 3.7 ±0.0 |
| react-starter-kit | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 2.7 ±0.0 | 2.8 ±0.0 |
| sure | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 9.3 ±0.2 | 9.6 ±0.0 |

### ZJIT total_mem_bytes after 5,000 requests, MB

| app | r4010-interpreter r81 | r4010-interpreter main | r4010-zjit r81 | r4010-zjit main | master-interpreter r81 | master-interpreter main | master-zjit r81 | master-zjit main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | 0.0 ±0.0 | 0.0 ±0.0 | 32.7 ±0.0 | 34.4 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 29.4 ±0.0 | 30.4 ±0.1 |
| writebook | 0.0 ±0.0 | 0.0 ±0.0 | 35.5 ±0.0 | 37.1 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 37.5 ±0.0 | 38.6 ±0.0 |
| pingcrm | 0.0 ±0.0 | 0.0 ±0.0 | 32.6 ±0.0 | 33.5 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 28.4 ±0.0 | 29.0 ±0.0 |
| redprints-cfp | 0.0 ±0.0 | 0.0 ±0.0 | 62.8 ±47.0 | 50.1 ±19.2 | 0.0 ±0.0 | 0.0 ±0.0 | 30.6 ±0.2 | 31.7 ±0.1 |
| react-starter-kit | 0.0 ±0.0 | 0.0 ±0.0 | 28.5 ±0.0 | 29.4 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 22.1 ±0.0 | 22.9 ±0.0 |
| sure | 0.0 ±0.0 | 0.0 ±0.0 | 115.2 ±15.4 | 125.3 ±0.0 | 0.0 ±0.0 | 0.0 ±0.0 | 79.5 ±0.9 | 81.1 ±0.2 |

## Differences

### RssAnon after boot, MB

| app | Rails main − 8.1, r4010-interpreter | Rails main − 8.1, r4010-zjit | Rails main − 8.1, master-interpreter | Rails main − 8.1, master-zjit | Ruby master − 4.0.10, interpreter, r81 | Ruby master − 4.0.10, interpreter, main | Ruby master − 4.0.10, zjit, r81 | Ruby master − 4.0.10, zjit, main | ZJIT − interpreter, r4010, main | ZJIT − interpreter, master, main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | +2.6 (A/A 1.5) | +4.6 (A/A 0.1) | +3.3 (A/A 0.4) | +3.7 (A/A 0.2) | -10.6 (A/A 1.5) | -9.9 (A/A 0.3) | -16.0 (A/A 0.1) | -16.9 (A/A 0.2) | +17.0 (A/A 0.2) | +10.0 (A/A 0.3) |
| writebook | +7.1 (A/A 7.1) | +3.4 (A/A 0.0) | +2.2 (A/A 2.3) | +4.0 (A/A 0.1) | -9.4 (A/A 7.1) | -14.3 (A/A 2.3) | -23.4 (A/A 0.0) | -22.8 (A/A 0.1) | +17.3 (A/A 0.1) | +8.9 (A/A 2.3) |
| pingcrm | -6.3 (A/A 27.0) | +1.7 (A/A 2.3) | -2.8 (A/A 11.1) | +4.2 (A/A 1.1) | -19.7 (A/A 27.0) | -16.2 (A/A 8.6) | -22.5 (A/A 0.3) | -20.0 (A/A 2.3) | +14.6 (A/A 8.6) | +10.8 (A/A 2.5) |
| redprints-cfp | -5.3 (A/A 33.4) | -13.1 (A/A 67.8) | -3.3 (A/A 16.6) | -0.1 (A/A 18.8) | -19.5 (A/A 33.4) | -17.5 (A/A 2.7) | -46.9 (A/A 67.8) | -33.9 (A/A 29.2) | +34.6 (A/A 29.2) | +18.1 (A/A 10.0) |
| react-starter-kit | +2.2 (A/A 6.2) | +5.4 (A/A 1.8) | -2.8 (A/A 11.3) | +3.5 (A/A 0.2) | -8.9 (A/A 11.3) | -13.9 (A/A 6.2) | -16.4 (A/A 1.0) | -18.3 (A/A 1.8) | +14.1 (A/A 6.2) | +9.7 (A/A 0.9) |
| sure | -7.8 (A/A 6.0) | +14.6 (A/A 7.1) | -9.6 (A/A 2.7) | -12.9 (A/A 24.4) | -51.7 (A/A 6.0) | -53.4 (A/A 2.7) | -99.1 (A/A 7.1) | -126.6 (A/A 24.4) | +85.8 (A/A 0.7) | +12.6 (A/A 24.4) |

### GC heap after boot, MB

| app | Rails main − 8.1, r4010-interpreter | Rails main − 8.1, r4010-zjit | Rails main − 8.1, master-interpreter | Rails main − 8.1, master-zjit | Ruby master − 4.0.10, interpreter, r81 | Ruby master − 4.0.10, interpreter, main | Ruby master − 4.0.10, zjit, r81 | Ruby master − 4.0.10, zjit, main | ZJIT − interpreter, r4010, main | ZJIT − interpreter, master, main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | +3.0 (A/A 0.1) | +2.8 (A/A 0.0) | +2.5 (A/A 0.1) | +2.6 (A/A 0.2) | -4.6 (A/A 0.1) | -5.1 (A/A 0.1) | -3.8 (A/A 0.2) | -4.0 (A/A 0.0) | -0.2 (A/A 0.1) | +0.9 (A/A 0.1) |
| writebook | +2.5 (A/A 0.0) | +2.3 (A/A 0.0) | +2.1 (A/A 0.0) | +2.1 (A/A 0.0) | -5.2 (A/A 0.0) | -5.7 (A/A 0.0) | -4.7 (A/A 0.0) | -4.9 (A/A 0.0) | +0.1 (A/A 0.0) | +0.8 (A/A 0.0) |
| pingcrm | +2.3 (A/A 0.6) | +2.3 (A/A 0.0) | +2.0 (A/A 0.1) | +2.0 (A/A 0.0) | -6.1 (A/A 0.6) | -6.4 (A/A 0.1) | -5.1 (A/A 0.0) | -5.3 (A/A 0.0) | -0.2 (A/A 0.1) | +0.8 (A/A 0.0) |
| redprints-cfp | +3.5 (A/A 0.6) | +3.6 (A/A 0.1) | +3.3 (A/A 0.1) | +3.3 (A/A 0.1) | -7.4 (A/A 0.6) | -7.6 (A/A 0.1) | -6.3 (A/A 0.1) | -6.6 (A/A 0.0) | -0.1 (A/A 0.1) | +1.0 (A/A 0.1) |
| react-starter-kit | +3.2 (A/A 0.6) | +3.2 (A/A 0.0) | +2.8 (A/A 0.1) | +2.8 (A/A 0.0) | -5.6 (A/A 0.6) | -6.0 (A/A 0.1) | -4.6 (A/A 0.0) | -5.0 (A/A 0.0) | -0.2 (A/A 0.1) | +0.8 (A/A 0.1) |
| sure | +2.7 (A/A 0.0) | +2.5 (A/A 0.1) | +2.1 (A/A 0.1) | +2.2 (A/A 0.2) | -23.7 (A/A 0.0) | -24.3 (A/A 0.1) | -22.4 (A/A 0.1) | -22.6 (A/A 0.2) | -0.3 (A/A 0.0) | +1.3 (A/A 0.2) |

### RssAnon after 1,000 requests, MB

| app | Rails main − 8.1, r4010-interpreter | Rails main − 8.1, r4010-zjit | Rails main − 8.1, master-interpreter | Rails main − 8.1, master-zjit | Ruby master − 4.0.10, interpreter, r81 | Ruby master − 4.0.10, interpreter, main | Ruby master − 4.0.10, zjit, r81 | Ruby master − 4.0.10, zjit, main | ZJIT − interpreter, r4010, main | ZJIT − interpreter, master, main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | +1.3 (A/A 0.8) | +8.6 (A/A 0.7) | +3.0 (A/A 2.8) | +4.7 (A/A 0.4) | -10.9 (A/A 2.8) | -9.3 (A/A 0.8) | -11.7 (A/A 0.7) | -15.6 (A/A 0.6) | +42.2 (A/A 0.8) | +35.9 (A/A 0.3) |
| writebook | +3.3 (A/A 4.8) | +3.3 (A/A 0.7) | +4.1 (A/A 4.2) | +8.5 (A/A 0.3) | -10.8 (A/A 4.8) | -10.0 (A/A 4.2) | -13.7 (A/A 0.6) | -8.6 (A/A 0.7) | +37.8 (A/A 0.7) | +39.3 (A/A 4.2) |
| pingcrm | -7.1 (A/A 26.3) | +5.1 (A/A 0.6) | -0.3 (A/A 9.7) | +6.5 (A/A 1.3) | -17.5 (A/A 26.3) | -10.8 (A/A 8.1) | -17.6 (A/A 1.3) | -16.1 (A/A 1.1) | +34.8 (A/A 8.1) | +29.4 (A/A 2.9) |
| redprints-cfp | +3.1 (A/A 31.7) | -7.3 (A/A 50.8) | -4.7 (A/A 12.1) | +2.1 (A/A 10.5) | -15.8 (A/A 31.7) | -23.6 (A/A 12.0) | -54.1 (A/A 50.8) | -44.6 (A/A 4.9) | +56.5 (A/A 12.0) | +35.5 (A/A 5.5) |
| react-starter-kit | +3.2 (A/A 21.1) | +7.0 (A/A 1.3) | -2.7 (A/A 12.0) | +7.4 (A/A 0.9) | -15.5 (A/A 17.5) | -21.4 (A/A 21.1) | -20.2 (A/A 1.3) | -19.8 (A/A 1.1) | +25.1 (A/A 21.1) | +26.6 (A/A 0.9) |
| sure | -6.9 (A/A 36.5) | +7.9 (A/A 11.2) | +8.3 (A/A 20.6) | -7.4 (A/A 21.8) | -89.7 (A/A 36.5) | -74.5 (A/A 28.5) | -96.0 (A/A 16.4) | -111.2 (A/A 21.8) | +99.1 (A/A 28.5) | +62.4 (A/A 21.8) |

### GC heap after 1,000 requests, MB

| app | Rails main − 8.1, r4010-interpreter | Rails main − 8.1, r4010-zjit | Rails main − 8.1, master-interpreter | Rails main − 8.1, master-zjit | Ruby master − 4.0.10, interpreter, r81 | Ruby master − 4.0.10, interpreter, main | Ruby master − 4.0.10, zjit, r81 | Ruby master − 4.0.10, zjit, main | ZJIT − interpreter, r4010, main | ZJIT − interpreter, master, main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | +2.7 (A/A 0.2) | +2.4 (A/A 0.1) | +2.2 (A/A 0.1) | +2.3 (A/A 0.2) | -2.7 (A/A 0.2) | -3.2 (A/A 0.1) | -2.2 (A/A 0.2) | -2.3 (A/A 0.0) | +0.1 (A/A 0.1) | +0.9 (A/A 0.1) |
| writebook | +2.6 (A/A 0.0) | +2.1 (A/A 0.0) | +2.1 (A/A 0.0) | +2.2 (A/A 0.0) | -5.4 (A/A 0.0) | -5.8 (A/A 0.0) | -6.0 (A/A 0.0) | -6.0 (A/A 0.0) | +1.0 (A/A 0.0) | +0.8 (A/A 0.0) |
| pingcrm | +2.4 (A/A 0.6) | +2.4 (A/A 0.0) | +2.1 (A/A 0.1) | +2.1 (A/A 0.0) | -6.2 (A/A 0.6) | -6.5 (A/A 0.1) | -5.2 (A/A 0.0) | -5.5 (A/A 0.0) | -0.2 (A/A 0.1) | +0.8 (A/A 0.0) |
| redprints-cfp | +3.7 (A/A 0.6) | +3.1 (A/A 0.9) | +3.4 (A/A 0.1) | +3.4 (A/A 0.1) | -7.5 (A/A 0.6) | -7.8 (A/A 0.1) | -7.3 (A/A 0.9) | -7.0 (A/A 0.0) | +0.2 (A/A 0.1) | +1.0 (A/A 0.1) |
| react-starter-kit | +3.1 (A/A 0.5) | +3.0 (A/A 0.0) | +2.7 (A/A 0.1) | +2.7 (A/A 0.0) | -5.7 (A/A 0.5) | -6.1 (A/A 0.1) | -5.0 (A/A 0.0) | -5.3 (A/A 0.0) | -0.0 (A/A 0.1) | +0.8 (A/A 0.1) |
| sure | +2.8 (A/A 0.2) | -0.2 (A/A 0.5) | +2.2 (A/A 0.2) | +2.3 (A/A 0.1) | -23.4 (A/A 0.2) | -24.0 (A/A 0.1) | -45.3 (A/A 0.5) | -42.8 (A/A 0.1) | +20.1 (A/A 0.0) | +1.3 (A/A 0.1) |

### RssAnon growth per request (1,000 to 5,000), bytes

| app | Rails main − 8.1, r4010-interpreter | Rails main − 8.1, r4010-zjit | Rails main − 8.1, master-interpreter | Rails main − 8.1, master-zjit | Ruby master − 4.0.10, interpreter, r81 | Ruby master − 4.0.10, interpreter, main | Ruby master − 4.0.10, zjit, r81 | Ruby master − 4.0.10, zjit, main | ZJIT − interpreter, r4010, main | ZJIT − interpreter, master, main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | -227 (A/A 49) | +49 (A/A 99) | -62 (A/A 293) | -179 (A/A 414) | +345 (A/A 257) | +510 (A/A 293) | +1326 (A/A 414) | +1098 (A/A 261) | -31 (A/A 49) | +558 (A/A 293) |
| writebook | -1049 (A/A 1156) | -387 (A/A 159) | +401 (A/A 198) | -218 (A/A 109) | -56 (A/A 1156) | +1394 (A/A 198) | +237 (A/A 135) | +406 (A/A 159) | +1103 (A/A 159) | +115 (A/A 198) |
| pingcrm | +41 (A/A 294) | +74 (A/A 66) | +1180 (A/A 1251) | -1793 (A/A 1408) | +860 (A/A 1251) | +1998 (A/A 659) | +1718 (A/A 1408) | -149 (A/A 185) | -115 (A/A 113) | -2262 (A/A 659) |
| redprints-cfp | -148 (A/A 223) | +57 (A/A 281) | +736 (A/A 204) | +441 (A/A 1090) | -240 (A/A 204) | +644 (A/A 223) | +3 (A/A 7) | +387 (A/A 1090) | +12 (A/A 281) | -245 (A/A 1090) |
| react-starter-kit | +305 (A/A 2339) | -294 (A/A 375) | -318 (A/A 1778) | +1450 (A/A 48) | -911 (A/A 2101) | -1534 (A/A 2339) | -377 (A/A 48) | +1368 (A/A 375) | -1847 (A/A 2339) | +1055 (A/A 1406) |
| sure | -3370 (A/A 11521) | +30 (A/A 316) | -926 (A/A 6057) | +2821 (A/A 5830) | -48 (A/A 6057) | +2397 (A/A 11521) | +618 (A/A 5830) | +3410 (A/A 42) | +1903 (A/A 11521) | +2916 (A/A 410) |

### GC heap growth per request (1,000 to 5,000), bytes

| app | Rails main − 8.1, r4010-interpreter | Rails main − 8.1, r4010-zjit | Rails main − 8.1, master-interpreter | Rails main − 8.1, master-zjit | Ruby master − 4.0.10, interpreter, r81 | Ruby master − 4.0.10, interpreter, main | Ruby master − 4.0.10, zjit, r81 | Ruby master − 4.0.10, zjit, main | ZJIT − interpreter, r4010, main | ZJIT − interpreter, master, main |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| blog | +4 (A/A 12) | +4 (A/A 12) | -73 (A/A 149) | +2 (A/A 1) | +86 (A/A 149) | +9 (A/A 1) | +9 (A/A 12) | +7 (A/A 0) | +0 (A/A 0) | -1 (A/A 1) |
| writebook | -3 (A/A 0) | -3 (A/A 0) | -3 (A/A 1) | -4 (A/A 0) | +261 (A/A 0) | +261 (A/A 1) | +262 (A/A 0) | +261 (A/A 0) | -0 (A/A 0) | -0 (A/A 1) |
| pingcrm | -0 (A/A 0) | -1 (A/A 0) | -0 (A/A 0) | +0 (A/A 0) | +261 (A/A 0) | +262 (A/A 0) | +261 (A/A 0) | +261 (A/A 0) | +0 (A/A 0) | -0 (A/A 0) |
| redprints-cfp | -0 (A/A 1) | +131 (A/A 261) | +0 (A/A 0) | +0 (A/A 0) | +262 (A/A 1) | +262 (A/A 0) | +131 (A/A 261) | +0 (A/A 0) | +261 (A/A 0) | -1 (A/A 0) |
| react-starter-kit | +0 (A/A 0) | +0 (A/A 0) | +0 (A/A 0) | -0 (A/A 0) | +0 (A/A 0) | +0 (A/A 0) | +0 (A/A 0) | -0 (A/A 0) | +0 (A/A 0) | -0 (A/A 0) |
| sure | -0 (A/A 0) | -0 (A/A 0) | -0 (A/A 0) | +1 (A/A 2) | -0 (A/A 0) | -0 (A/A 0) | -1 (A/A 2) | +0 (A/A 1) | +0 (A/A 0) | +0 (A/A 1) |

