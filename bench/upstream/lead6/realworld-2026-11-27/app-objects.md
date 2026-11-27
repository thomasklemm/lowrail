## interp
| workload | main | main2 | fix2 | l6 |
| GET dashboard | 13446.2 | 13436.0 (-10.2) | 13438.5 (-7.7) | 13441.8 (-4.4) |
| GET projects | 7587.4 | 7586.7 (-0.7) | 7583.9 (-3.5) | 7591.1 (3.7) |
| GET leaderboards | 6462.6 | 6461.1 (-1.5) | 6458.4 (-4.2) | 6464.1 (1.5) |
| GET settings profile | 7861.6 | 7858.9 (-2.7) | 7860.5 (-1.1) | 7866.1 (4.5) |
| GET dashboard (Inertia XHR) | 12273.9 | 12277.1 (3.2) | 12275.0 (1.1) | 12273.9 (0.0) |
| GET dashboard stats (deferred) | 10215.9 | 10213.0 (-2.9) | 10223.7 (7.8) | 10222.0 (6.1) |
| GET leaderboard entries (deferred) | 2655.9 | 2654.8 (-1.1) | 2654.7 (-1.2) | 2654.3 (-1.6) |
| PATCH display name (Inertia redirect) | 2948.0 | 2942.8 (-5.2) | 2919.8 (-28.2) | 2942.3 (-5.7) |
| PATCH username invalid (Inertia 422) | 7979.2 | 7985.4 (6.2) | 7980.2 (1.0) | 7988.2 (9.0) |
| GET statusbar today | 2420.5 | 2424.9 (4.4) | 2424.3 (3.8) | 2423.6 (3.1) |
| POST heartbeat | 4183.5 | 4180.8 (-2.7) | 4178.7 (-4.8) | 4179.2 (-4.3) |
## yjit
| workload | main | main2 | fix2 | l6 |
| GET dashboard | 13470.1 | 13467.0 (-3.1) | 13611.6 (141.5) | 13471.0 (0.9) |
| GET projects | 7609.9 | 7606.1 (-3.8) | 7604.7 (-5.2) | 7610.0 (0.1) |
| GET leaderboards | 6463.2 | 6462.0 (-1.2) | 6462.9 (-0.3) | 6458.9 (-4.3) |
| GET settings profile | 7869.4 | 7869.6 (0.2) | 7873.9 (4.5) | 7870.4 (1.0) |
| GET dashboard (Inertia XHR) | 12299.5 | 12303.6 (4.1) | 12305.8 (6.3) | 12305.0 (5.5) |
| GET dashboard stats (deferred) | 10254.3 | 10250.4 (-3.9) | 10249.3 (-5.0) | 10246.3 (-8.0) |
| GET leaderboard entries (deferred) | 2660.9 | 2657.2 (-3.7) | 2660.2 (-0.7) | 2661.4 (0.5) |
| PATCH display name (Inertia redirect) | 2948.2 | 2951.5 (3.3) | 2919.9 (-28.3) | 2956.7 (8.5) |
| PATCH username invalid (Inertia 422) | 7993.2 | 7989.5 (-3.7) | 7996.6 (3.4) | 7989.8 (-3.4) |
| GET statusbar today | 2437.5 | 2436.5 (-1.0) | 2435.6 (-1.9) | 2437.8 (0.3) |
| POST heartbeat | 4196.2 | 4200.3 (4.1) | 4204.5 (8.3) | 4204.8 (8.6) |
