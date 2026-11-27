an.rb:13:in 'block in <main>': undefined method '+' for nil (NoMethodError)

med = ->(a) { s = a.sort; n = s.size; n.odd? ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2.0 }
                                                                        ^
	from an.rb:44:in 'block in <main>'
	from an.rb:36:in 'Array#each'
	from an.rb:36:in '<main>'
# app-hackatime.jsonl: per-process median of windows, mean of per-round log ratios vs main, 95% bootstrap CI over rounds
| mode | cols | case | main ns/call | main2 vs main [95% CI] | l6 vs main [95% CI] | rounds |
|---|---:|---|---:|---:|---:|---:|
| interp | 0 | GET dashboard | 18417193 | -0.66% [-8.22%, +8.13%] | -5.10% [-10.40%, -0.57%] | 10 |
| interp | 0 | GET dashboard (Inertia XHR) | 15866302 | +3.39% [-2.21%, +10.46%] | -2.28% [-6.15%, +1.85%] | 10 |
| interp | 0 | GET dashboard stats (deferred) | 12215669 | +0.41% [-2.41%, +3.28%] | -2.35% [-6.91%, +2.60%] | 10 |
| interp | 0 | GET leaderboard entries (deferred) | 4695095 | +0.51% [-5.00%, +5.13%] | -4.78% [-10.21%, +0.34%] | 10 |
| interp | 0 | GET leaderboards | 10452671 | +1.31% [-2.97%, +5.71%] | -0.49% [-4.86%, +4.50%] | 10 |
| interp | 0 | GET projects | 12964762 | +2.53% [-5.94%, +11.11%] | -0.89% [-7.49%, +5.24%] | 10 |
| interp | 0 | GET settings profile | 11344688 | +2.35% [-4.49%, +10.64%] | -1.12% [-5.94%, +4.59%] | 10 |
| interp | 0 | GET statusbar today | 4798083 | +0.56% [-2.24%, +3.43%] | -2.53% [-5.83%, +1.34%] | 10 |
| interp | 0 | PATCH display name (Inertia redirect) | 6166370 | -0.06% [-5.57%, +5.40%] | -4.19% [-7.26%, -1.53%] | 10 |
| interp | 0 | PATCH username invalid (Inertia 422) | 11745020 | +0.43% [-4.27%, +4.81%] | -0.34% [-2.66%, +2.62%] | 10 |
| interp | 0 | POST heartbeat | 8125561 | +4.56% [-2.15%, +12.75%] | -1.54% [-5.65%, +2.77%] | 10 |
| interp | 0 | perform DashboardRollupRefreshJob | 18075651 | +4.01% [+0.51%, +7.64%] | n/a | 2 |
| yjit | 0 | GET dashboard | 10410124 | -1.78% [-8.01%, +3.61%] | -0.30% [-3.91%, +3.61%] | 10 |
| yjit | 0 | GET dashboard (Inertia XHR) | 8940603 | -0.39% [-4.69%, +3.77%] | +1.70% [-2.90%, +5.99%] | 10 |
| yjit | 0 | GET dashboard stats (deferred) | 6902966 | +0.90% [-3.31%, +4.81%] | -0.84% [-5.86%, +3.57%] | 10 |
| yjit | 0 | GET leaderboard entries (deferred) | 2831242 | -3.13% [-7.25%, +0.93%] | -0.75% [-3.60%, +2.35%] | 10 |
| yjit | 0 | GET leaderboards | 6235873 | +0.20% [-6.32%, +6.96%] | -0.60% [-4.24%, +3.27%] | 10 |
| yjit | 0 | GET projects | 8146099 | -2.85% [-9.70%, +3.18%] | +0.94% [-3.67%, +4.97%] | 10 |
| yjit | 0 | GET settings profile | 7347782 | -0.48% [-4.67%, +4.43%] | +1.59% [-3.04%, +6.52%] | 10 |
| yjit | 0 | GET statusbar today | 2791368 | +1.06% [-3.69%, +6.56%] | +0.44% [-3.12%, +4.27%] | 10 |
| yjit | 0 | PATCH display name (Inertia redirect) | 3875705 | -3.65% [-8.13%, +0.13%] | -1.13% [-4.62%, +2.34%] | 10 |
| yjit | 0 | PATCH username invalid (Inertia 422) | 7451783 | -1.65% [-7.86%, +4.49%] | -0.85% [-4.28%, +2.70%] | 10 |
| yjit | 0 | POST heartbeat | 5001139 | +2.44% [-1.98%, +7.20%] | -1.64% [-5.84%, +1.85%] | 10 |
