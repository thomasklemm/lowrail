an.rb:13:in 'block in <main>': undefined method '+' for nil (NoMethodError)

med = ->(a) { s = a.sort; n = s.size; n.odd? ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2.0 }
                                                                        ^
	from an.rb:44:in 'block in <main>'
	from an.rb:36:in 'Array#each'
	from an.rb:36:in '<main>'
# app-hackatime.jsonl: per-process median of windows, mean of per-round log ratios vs main, 95% bootstrap CI over rounds
| mode | cols | case | main ns/call | main2 vs main [95% CI] | l6 vs main [95% CI] | rounds |
|---|---:|---|---:|---:|---:|---:|
| interp | 0 | GET dashboard | 22630114 | -1.29% [-8.68%, +8.10%] | -7.31% [-13.00%, -2.03%] | 10 |
| interp | 0 | GET dashboard (Inertia XHR) | 19902697 | +3.10% [-3.30%, +10.68%] | -3.69% [-8.44%, +1.31%] | 10 |
| interp | 0 | GET dashboard stats (deferred) | 16391666 | -1.05% [-4.16%, +2.23%] | -5.40% [-9.90%, -0.22%] | 10 |
| interp | 0 | GET leaderboard entries (deferred) | 5132675 | +0.39% [-5.35%, +5.50%] | -5.95% [-10.99%, -1.20%] | 10 |
| interp | 0 | GET leaderboards | 11605673 | +1.58% [-2.50%, +5.93%] | -1.08% [-6.07%, +4.92%] | 10 |
| interp | 0 | GET projects | 15823335 | +2.42% [-6.16%, +11.60%] | -2.06% [-8.89%, +4.08%] | 10 |
| interp | 0 | GET settings profile | 12607627 | +2.39% [-4.60%, +10.60%] | -1.57% [-7.09%, +4.85%] | 10 |
| interp | 0 | GET statusbar today | 5981386 | -0.41% [-4.77%, +4.13%] | -4.72% [-8.00%, -0.97%] | 10 |
| interp | 0 | PATCH display name (Inertia redirect) | 7216126 | -0.58% [-6.41%, +5.16%] | -5.86% [-9.25%, -2.85%] | 10 |
| interp | 0 | PATCH username invalid (Inertia 422) | 13076115 | -0.17% [-5.20%, +4.64%] | -2.06% [-3.99%, +0.04%] | 10 |
| interp | 0 | POST heartbeat | 10126529 | +4.05% [-3.23%, +13.16%] | -2.52% [-6.86%, +1.30%] | 10 |
| interp | 0 | perform DashboardRollupRefreshJob | 68161103 | +3.53% [+2.76%, +4.30%] | n/a | 2 |
| yjit | 0 | GET dashboard | 14411546 | -3.56% [-9.37%, +1.91%] | -0.63% [-5.21%, +4.13%] | 10 |
| yjit | 0 | GET dashboard (Inertia XHR) | 12433545 | -1.76% [-6.88%, +3.45%] | +2.16% [-2.98%, +8.19%] | 10 |
| yjit | 0 | GET dashboard stats (deferred) | 10081641 | +3.61% [-2.66%, +10.61%] | +2.72% [-1.31%, +6.69%] | 10 |
| yjit | 0 | GET leaderboard entries (deferred) | 3246456 | +1.26% [-4.09%, +7.55%] | +0.28% [-2.70%, +3.86%] | 10 |
| yjit | 0 | GET leaderboards | 7262357 | +0.14% [-6.70%, +7.42%] | -0.46% [-4.07%, +3.31%] | 10 |
| yjit | 0 | GET projects | 10724746 | -1.16% [-8.61%, +5.96%] | +0.82% [-3.72%, +4.68%] | 10 |
| yjit | 0 | GET settings profile | 8416701 | -1.63% [-6.14%, +3.48%] | +1.60% [-3.07%, +6.39%] | 10 |
| yjit | 0 | GET statusbar today | 3925552 | +2.85% [-2.88%, +9.03%] | +1.82% [-1.48%, +4.74%] | 10 |
| yjit | 0 | PATCH display name (Inertia redirect) | 4743819 | +3.55% [-5.89%, +15.73%] | +2.05% [-1.54%, +5.29%] | 10 |
| yjit | 0 | PATCH username invalid (Inertia 422) | 8732413 | -0.11% [-8.25%, +10.17%] | -0.78% [-4.73%, +3.27%] | 10 |
| yjit | 0 | POST heartbeat | 6878072 | +7.88% [-1.12%, +19.88%] | -0.25% [-4.85%, +4.29%] | 10 |
