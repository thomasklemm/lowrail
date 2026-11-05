## lobsters interp
| metric | base-a | A/A (base-b) | patch |
|---|---:|---:|---:|
| wall ms/itr | 917.47 / 998.48 / 937.72 | +9.8% / -3.0% / -3.2% | -0.3% / -8.9% / +0.9% |
| GC ms/itr | 25.07 / 29.82 / 27.17 | +16.7% / -5.2% / -8.4% | +3.5% / -13.7% / +1.7% |
| wall-GC ms/itr | 892.40 / 968.67 / 910.55 | +9.6% / -3.0% / -3.1% | -0.4% / -8.7% / +0.9% |
| minor/itr | 0.80 / 0.90 / 0.90 | +12.5% / +0.0% / +0.0% | +12.5% / +0.0% / +0.0% |
| major/itr | 0.00 / 0.00 / 0.00 | – / – / – | – / – / – |
| ms/minor (prof) | 23.29 / 28.16 / 24.26 | +10.6% / -17.4% / -11.4% | -1.8% / -22.8% / -3.8% |
| ms/major (prof) | – / – / – | – / – / – | – / – / – |
| mark ms/minor | 6.54 / 7.74 / 6.69 | +12.3% / -9.1% / -5.1% | +0.8% / -15.3% / +1.1% |
| mark ms/major | – / – / – | – / – / – | – / – / – |
| median mark ms/minor | 6.61 / 7.25 / 6.76 | +8.6% / -4.4% / -5.2% | -2.1% / -10.2% / +0.3% |
| median mark ms/major | – / – / – | – / – / – | – / – / – |
| fit ms/minor | – / – / – | – / – / – | – / – / – |
| fit ms/major | – / – / – | – / – / – | – / – / – |
| probe minor ms | 2.78 / 2.71 / 2.81 | +7.4% / +4.4% / +3.3% | +0.3% / +23.7% / -0.7% |
| probe major ms | 26.47 / 47.32 / 34.81 | +31.9% / -5.1% / +11.0% | +32.1% / -39.4% / -2.5% |

## lobsters yjit
| metric | base-a | A/A (base-b) | patch |
|---|---:|---:|---:|
| wall ms/itr | 620.13 / 571.66 / 552.86 | -5.4% / +3.7% / +6.4% | -7.8% / +3.2% / +8.1% |
| GC ms/itr | 29.35 / 28.42 / 26.10 | +22.6% / +2.7% / +2.4% | -6.7% / +2.5% / +9.4% |
| wall-GC ms/itr | 590.78 / 543.24 / 526.76 | -6.8% / +3.7% / +6.6% | -7.9% / +3.2% / +8.1% |
| minor/itr | 0.80 / 0.90 / 0.80 | +12.5% / +0.0% / +0.0% | +12.5% / +0.0% / +0.0% |
| major/itr | 0.00 / 0.00 / 0.00 | – / – / – | – / – / – |
| ms/minor (prof) | 27.34 / 26.31 / 25.01 | -5.6% / +2.6% / -5.2% | -17.1% / -6.8% / -7.7% |
| ms/major (prof) | – / – / – | – / – / – | – / – / – |
| mark ms/minor | 7.55 / 7.00 / 6.61 | -9.1% / +6.2% / +4.1% | -11.4% / +1.6% / +8.0% |
| mark ms/major | – / – / – | – / – / – | – / – / – |
| median mark ms/minor | 7.33 / 7.02 / 6.59 | -5.0% / +1.8% / +4.1% | -9.1% / +1.7% / +10.3% |
| median mark ms/major | – / – / – | – / – / – | – / – / – |
| fit ms/minor | – / – / – | – / – / – | – / – / – |
| fit ms/major | – / – / – | – / – / – | – / – / – |
| probe minor ms | 3.06 / 2.75 / 2.93 | -4.5% / +18.7% / +5.8% | -11.5% / +1.8% / -1.8% |
| probe major ms | 61.80 / 66.15 / 53.31 | -4.6% / +6.8% / +16.1% | -15.2% / +2.2% / -23.4% |

## lobsters zjit
| metric | base-a | A/A (base-b) | patch |
|---|---:|---:|---:|
| wall ms/itr | 630.64 / 625.77 / 589.93 | +3.3% / -1.6% / +0.4% | +2.8% / +0.7% / -3.1% |
| GC ms/itr | 24.27 / 23.64 / 26.99 | +16.7% / +23.8% / +4.0% | +17.3% / +3.7% / -20.1% |
| wall-GC ms/itr | 606.37 / 602.14 / 562.94 | +2.7% / -2.6% / +0.2% | +2.2% / +0.6% / -2.3% |
| minor/itr | 0.80 / 0.80 / 0.70 | +12.5% / -12.5% / +0.0% | -12.5% / +0.0% / +14.3% |
| major/itr | 0.00 / 0.00 / 0.10 | – / – / +0.0% | – / – / -100.0% |
| ms/minor (prof) | 27.74 / 29.45 / 26.75 | +13.1% / +0.1% / +4.1% | -0.3% / +3.6% / +0.4% |
| ms/major (prof) | – / – / 17.44 | – / – / +8.7% | – / – / – |
| mark ms/minor | 7.63 / 7.62 / 6.90 | +1.2% / -2.0% / +1.9% | -9.5% / -7.7% / -10.2% |
| mark ms/major | – / – / 66.10 | – / – / +2.0% | – / – / – |
| median mark ms/minor | 7.75 / 7.70 / 7.05 | -1.6% / -3.1% / +0.9% | -13.2% / -8.0% / -13.0% |
| median mark ms/major | – / – / 66.10 | – / – / +2.0% | – / – / – |
| fit ms/minor | – / – / 26.85 | – / – / +4.2% | – / – / – |
| fit ms/major | – / – / 82.02 | – / – / +3.6% | – / – / – |
| probe minor ms | 3.56 / 2.90 / 3.16 | -5.9% / +7.6% / +0.1% | -5.1% / -1.1% / -11.0% |
| probe major ms | 69.19 / 40.88 / 40.60 | -26.2% / +14.3% / -0.5% | -2.2% / +63.1% / -5.0% |

## railsbench interp
| metric | base-a | A/A (base-b) | patch |
|---|---:|---:|---:|
| wall ms/itr | 2517.43 / 2356.01 / 2367.99 | -1.4% / +2.0% / +1.2% | -0.3% / +6.2% / +2.0% |
| GC ms/itr | 61.42 / 47.67 / 47.28 | -9.1% / +3.4% / -1.0% | -5.6% / +31.1% / +11.5% |
| wall-GC ms/itr | 2456.01 / 2308.34 / 2320.71 | -1.2% / +2.0% / +1.3% | -0.2% / +5.7% / +1.8% |
| minor/itr | 9.70 / 10.30 / 9.50 | -3.1% / -6.8% / +1.1% | -1.0% / -2.9% / +3.2% |
| major/itr | 0.00 / 0.00 / 0.00 | – / – / – | – / – / – |
| ms/minor (prof) | 6.17 / 4.49 / 4.83 | -5.1% / +12.3% / -0.9% | -3.9% / +38.0% / +9.8% |
| ms/major (prof) | – / – / – | – / – / – | – / – / – |
| mark ms/minor | 0.16 / 0.13 / 0.13 | -0.9% / +9.3% / -1.0% | -0.2% / +19.4% / +5.4% |
| mark ms/major | – / – / – | – / – / – | – / – / – |
| median mark ms/minor | 0.16 / 0.12 / 0.13 | -7.1% / +12.1% / -1.8% | -0.6% / +21.2% / +5.3% |
| median mark ms/major | – / – / – | – / – / – | – / – / – |
| fit ms/minor | – / – / – | – / – / – | – / – / – |
| fit ms/major | – / – / – | – / – / – | – / – / – |
| probe minor ms | 0.74 / 0.77 / 0.72 | +8.9% / -15.8% / +3.7% | -8.0% / -0.3% / +8.1% |
| probe major ms | 15.96 / 15.70 / 14.79 | +4.0% / -5.1% / +5.5% | +1.1% / +2.6% / -0.8% |

## railsbench yjit
| metric | base-a | A/A (base-b) | patch |
|---|---:|---:|---:|
| wall ms/itr | 1195.04 / 1135.59 / 1125.86 | -4.0% / +4.9% / +0.0% | -1.7% / -2.5% / +0.5% |
| GC ms/itr | 49.30 / 43.29 / 37.75 | -18.0% / +8.2% / +10.2% | -16.7% / -12.1% / +3.8% |
| wall-GC ms/itr | 1145.74 / 1092.30 / 1088.11 | -3.4% / +4.8% / -0.3% | -1.0% / -2.1% / +0.4% |
| minor/itr | 9.30 / 8.50 / 8.70 | +6.5% / +5.9% / -5.7% | +7.5% / +16.5% / +12.6% |
| major/itr | 0.00 / 0.10 / 0.00 | – / +0.0% / – | – / -100.0% / – |
| ms/minor (prof) | 5.13 / 4.52 / 4.28 | -22.4% / +0.9% / +15.0% | -21.6% / -17.4% / -8.5% |
| ms/major (prof) | – / 4.07 / – | – / +42.0% / – | – / – / – |
| mark ms/minor | 0.20 / 0.16 / 0.16 | -22.7% / +10.1% / +18.0% | -15.4% / -13.4% / -9.7% |
| mark ms/major | – / 35.59 / – | – / +34.2% / – | – / – / – |
| median mark ms/minor | 0.19 / 0.16 / 0.15 | -25.4% / +7.0% / +23.8% | -19.3% / -16.2% / -10.5% |
| median mark ms/major | – / 35.59 / – | – / +34.2% / – | – / – / – |
| fit ms/minor | – / 4.66 / – | – / -2.4% / – | – / – / – |
| fit ms/major | – / 36.23 / – | – / +62.1% / – | – / – / – |
| probe minor ms | 0.73 / 0.67 / 0.67 | +4.3% / +11.1% / +12.5% | -9.5% / +17.2% / +18.2% |
| probe major ms | 18.79 / 18.17 / 18.90 | -0.9% / -0.3% / -1.4% | +36.5% / +4.3% / +0.5% |

## railsbench zjit
| metric | base-a | A/A (base-b) | patch |
|---|---:|---:|---:|
| wall ms/itr | 1337.75 / 1306.38 / 1361.51 | -0.9% / +3.1% / -2.7% | -4.1% / +6.3% / -3.1% |
| GC ms/itr | 41.94 / 44.15 / 44.56 | +5.7% / +12.6% / -7.1% | -3.6% / +9.2% / -11.6% |
| wall-GC ms/itr | 1295.81 / 1262.23 / 1316.95 | -1.2% / +2.8% / -2.6% | -4.1% / +6.2% / -2.8% |
| minor/itr | 8.00 / 8.50 / 8.10 | +5.0% / -1.2% / +1.2% | +20.0% / +21.2% / +22.2% |
| major/itr | 0.00 / 0.00 / 0.00 | – / – / – | – / – / – |
| ms/minor (prof) | 5.04 / 5.10 / 5.43 | +2.5% / +13.2% / -9.1% | -18.7% / -10.9% / -28.3% |
| ms/major (prof) | – / – / – | – / – / – | – / – / – |
| mark ms/minor | 0.34 / 0.35 / 0.36 | +2.8% / +8.4% / -8.8% | -54.2% / -48.9% / -58.6% |
| mark ms/major | – / – / – | – / – / – | – / – / – |
| median mark ms/minor | 0.33 / 0.34 / 0.36 | +6.5% / +10.6% / -8.8% | -56.0% / -50.1% / -61.0% |
| median mark ms/major | – / – / – | – / – / – | – / – / – |
| fit ms/minor | – / – / – | – / – / – | – / – / – |
| fit ms/major | – / – / – | – / – / – | – / – / – |
| probe minor ms | 0.87 / 0.84 / 0.89 | +0.5% / +18.6% / -0.3% | -21.3% / -14.5% / -19.1% |
| probe major ms | 18.00 / 20.40 / 17.02 | +18.4% / -5.5% / +5.9% | -8.0% / -6.0% / +19.3% |

## shipit interp
| metric | base-a | A/A (base-b) | patch |
|---|---:|---:|---:|
| wall ms/itr | 1783.40 / 1688.16 / 1615.25 | -3.3% / -2.0% / -0.2% | -0.4% / -3.8% / +3.0% |
| GC ms/itr | 62.26 / 53.51 / 54.39 | -11.1% / -1.4% / -3.9% | -3.2% / -3.5% / -6.1% |
| wall-GC ms/itr | 1721.14 / 1634.65 / 1560.86 | -3.0% / -2.0% / -0.0% | -0.2% / -3.8% / +3.3% |
| minor/itr | 4.30 / 3.50 / 3.90 | -11.6% / +8.6% / +2.6% | -9.3% / +17.1% / -2.6% |
| major/itr | 0.30 / 0.20 / 0.30 | -33.3% / +0.0% / +0.0% | +0.0% / +0.0% / -33.3% |
| ms/minor (prof) | 10.08 / 10.70 / 8.99 | +5.8% / -3.1% / -4.4% | +1.6% / -11.3% / +9.0% |
| ms/major (prof) | 8.23 / 4.96 / 8.57 | +22.2% / +36.8% / -20.1% | -13.1% / -10.7% / -23.8% |
| mark ms/minor | 2.69 / 3.03 / 2.42 | +7.7% / -7.5% / -7.3% | +7.3% / -16.3% / +9.2% |
| mark ms/major | 50.85 / 46.09 / 49.37 | +6.2% / +10.1% / -2.5% | +1.1% / +6.5% / +0.7% |
| median mark ms/minor | 2.74 / 2.96 / 2.50 | +7.7% / -8.7% / -8.5% | +1.2% / -12.8% / +10.5% |
| median mark ms/major | 49.99 / 56.14 / 47.51 | +13.9% / -9.2% / +0.7% | +2.4% / -11.8% / +11.0% |
| fit ms/minor | 10.93 / 12.23 / 9.37 | +1.1% / -12.8% / -5.7% | +0.9% / -16.8% / +11.9% |
| fit ms/major | 48.50 / 48.46 / 58.43 | +27.8% / +14.8% / -6.8% | +15.1% / -4.8% / -11.0% |
| probe minor ms | 1.59 / 1.49 / 1.55 | +4.3% / +17.8% / +4.8% | +16.0% / -9.5% / +7.0% |
| probe major ms | 27.69 / 22.92 / 23.26 | +32.2% / +17.4% / +7.7% | -10.9% / -3.2% / +6.5% |

## shipit yjit
| metric | base-a | A/A (base-b) | patch |
|---|---:|---:|---:|
| wall ms/itr | 851.60 / 797.77 / 754.04 | -11.4% / -4.1% / +2.1% | -11.2% / -0.5% / +7.3% |
| GC ms/itr | 67.91 / 62.51 / 56.10 | -21.9% / -12.6% / -6.6% | -23.2% / -2.5% / +12.1% |
| wall-GC ms/itr | 783.70 / 735.26 / 697.94 | -10.5% / -3.3% / +2.8% | -10.1% / -0.3% / +6.9% |
| minor/itr | 3.90 / 3.90 / 3.80 | -2.6% / -7.7% / +2.6% | -5.1% / +2.6% / +5.3% |
| major/itr | 0.30 / 0.30 / 0.30 | +0.0% / +0.0% / -33.3% | +0.0% / +0.0% / +0.0% |
| ms/minor (prof) | 10.75 / 10.01 / 8.46 | -27.1% / -17.0% / +11.1% | -27.9% / -0.2% / +11.1% |
| ms/major (prof) | 6.85 / 7.04 / 8.23 | +17.3% / +28.1% / +8.7% | -16.7% / -32.1% / +12.0% |
| mark ms/minor | 2.98 / 2.76 / 2.38 | -32.0% / -18.5% / +3.3% | -32.1% / +1.5% / +8.7% |
| mark ms/major | 66.69 / 65.87 / 64.65 | -4.0% / -0.6% / +3.9% | -9.0% / -14.1% / +3.9% |
| median mark ms/minor | 3.04 / 2.82 / 2.35 | -34.8% / -20.7% / +7.0% | -35.0% / -1.0% / +11.6% |
| median mark ms/major | 67.19 / 65.79 / 66.19 | -5.9% / -0.7% / +3.0% | -6.1% / -0.3% / +2.1% |
| fit ms/minor | 11.78 / 10.54 / 9.09 | -29.9% / -17.8% / +4.3% | -27.7% / -2.1% / +10.8% |
| fit ms/major | 69.92 / 69.93 / 69.85 | +0.6% / +8.2% / +7.5% | -8.0% / -15.3% / +4.6% |
| probe minor ms | 1.78 / 1.62 / 1.62 | -3.4% / +3.2% / +15.3% | -4.1% / +3.9% / +1.8% |
| probe major ms | 54.08 / 50.30 / 42.21 | -37.2% / -16.8% / -8.7% | -40.0% / -15.6% / +18.9% |

## shipit zjit
| metric | base-a | A/A (base-b) | patch |
|---|---:|---:|---:|
| wall ms/itr | 1009.18 / 978.64 / 1056.83 | +3.6% / -2.8% / -3.4% | +0.6% / -0.9% / +1.6% |
| GC ms/itr | 72.98 / 66.81 / 63.91 | +3.6% / -10.8% / +11.4% | -8.6% / -11.2% / -0.6% |
| wall-GC ms/itr | 936.20 / 911.83 / 992.92 | +3.6% / -2.2% / -4.4% | +1.3% / -0.1% / +1.7% |
| minor/itr | 4.10 / 4.20 / 4.10 | +7.3% / +2.4% / +2.4% | +14.6% / +4.8% / +2.4% |
| major/itr | 0.50 / 0.50 / 0.30 | +0.0% / -20.0% / +33.3% | -20.0% / -20.0% / +33.3% |
| ms/minor (prof) | 8.91 / 8.08 / 10.56 | +6.2% / -2.1% / -6.8% | -5.9% / -11.7% / -20.9% |
| ms/major (prof) | 8.11 / 6.50 / 7.98 | -11.2% / +3.7% / +3.6% | -12.9% / -1.4% / -16.0% |
| mark ms/minor | 3.02 / 2.74 / 3.48 | +4.5% / -4.4% / -4.6% | -22.8% / -29.7% / -33.0% |
| mark ms/major | 64.51 / 59.18 / 61.41 | -4.4% / -2.1% / +9.5% | -4.9% / +5.4% / +5.1% |
| median mark ms/minor | 3.07 / 2.65 / 3.47 | +0.6% / -0.0% / -5.9% | -25.2% / -29.7% / -33.8% |
| median mark ms/major | 61.30 / 58.51 / 60.79 | +0.7% / -0.1% / +3.0% | +3.6% / +6.0% / +10.0% |
| fit ms/minor | 8.87 / 8.28 / 10.72 | +6.9% / -2.1% / -6.0% | -1.7% / -13.5% / -23.9% |
| fit ms/major | 72.92 / 63.64 / 66.03 | -7.0% / -3.4% / +9.5% | -12.4% / +8.1% / +8.6% |
| probe minor ms | 2.68 / 2.20 / 2.03 | -25.1% / -21.9% / -2.7% | -41.3% / -32.2% / -23.7% |
| probe major ms | 44.13 / 45.21 / 36.18 | -6.2% / -33.5% / +16.0% | -22.0% / -31.3% / -2.1% |

## Pooled: base processes (base-a + base-b) vs patch processes
| bench mode | metric | base CV | patch effect | effect / SE |
|---|---|---:|---:|---:|
| lobsters interp | wall ms/itr | 4.4% | -3.4% | -1.1 |
| lobsters interp | GC ms/itr | 7.6% | -3.6% | -0.7 |
| lobsters interp | wall-GC ms/itr | 4.3% | -3.4% | -1.1 |
| lobsters interp | minor/itr | 4.6% | +1.9% | +0.6 |
| lobsters interp | major/itr | NaN% | +NaN% | – |
| lobsters interp | ms/minor (prof) | 9.5% | -7.1% | -1.1 |
| lobsters interp | mark ms/minor | 7.6% | -4.5% | -0.8 |
| lobsters interp | median mark ms/minor | 4.8% | -3.9% | -1.2 |
| lobsters interp | probe minor ms | 3.5% | +5.0% | +2.0 |
| lobsters interp | probe major ms | 20.0% | -14.0% | -1.0 |
| lobsters yjit | wall ms/itr | 3.8% | +0.2% | +0.1 |
| lobsters yjit | GC ms/itr | 12.0% | -3.2% | -0.4 |
| lobsters yjit | wall-GC ms/itr | 3.9% | +0.4% | +0.1 |
| lobsters yjit | minor/itr | 6.4% | +2.0% | +0.4 |
| lobsters yjit | major/itr | 244.9% | -100.0% | -0.6 |
| lobsters yjit | ms/minor (prof) | 5.2% | -9.4% | -2.6 |
| lobsters yjit | mark ms/minor | 5.1% | -1.1% | -0.3 |
| lobsters yjit | median mark ms/minor | 3.6% | +0.6% | +0.2 |
| lobsters yjit | probe minor ms | 5.9% | -7.0% | -1.7 |
| lobsters yjit | probe major ms | 9.6% | -13.7% | -2.0 |
| lobsters zjit | wall ms/itr | 3.8% | -0.2% | -0.1 |
| lobsters zjit | GC ms/itr | 8.6% | -7.2% | -1.2 |
| lobsters zjit | wall-GC ms/itr | 4.1% | +0.2% | +0.1 |
| lobsters zjit | minor/itr | 10.6% | +0.0% | +0.0 |
| lobsters zjit | major/itr | 109.5% | -33.3% | -0.4 |
| lobsters zjit | ms/minor (prof) | 5.7% | -1.5% | -0.4 |
| lobsters zjit | ms/major (prof) | 4.5% | +19.2% | +3.7 |
| lobsters zjit | mark ms/minor | 4.7% | -9.3% | -2.8 |
| lobsters zjit | mark ms/major | 1.6% | +2.8% | +1.6 |
| lobsters zjit | median mark ms/minor | 4.1% | -10.7% | -3.8 |
| lobsters zjit | median mark ms/major | 1.6% | +2.8% | +1.6 |
| lobsters zjit | fit ms/minor | 4.9% | -2.4% | -0.4 |
| lobsters zjit | fit ms/major | 2.2% | +9.8% | +3.8 |
| lobsters zjit | probe minor ms | 7.0% | -5.9% | -1.2 |
| lobsters zjit | probe major ms | 23.2% | +19.7% | +1.2 |
| railsbench interp | wall ms/itr | 2.7% | +2.3% | +1.2 |
| railsbench interp | GC ms/itr | 11.5% | +12.4% | +1.5 |
| railsbench interp | wall-GC ms/itr | 2.5% | +2.1% | +1.2 |
| railsbench interp | minor/itr | 3.3% | +1.2% | +0.5 |
| railsbench interp | major/itr | NaN% | +NaN% | – |
| railsbench interp | ms/minor (prof) | 12.8% | +11.8% | +1.3 |
| railsbench interp | mark ms/minor | 9.8% | +6.4% | +0.9 |
| railsbench interp | median mark ms/minor | 9.9% | +7.6% | +1.1 |
| railsbench interp | probe minor ms | 7.2% | +0.5% | +0.1 |
| railsbench interp | probe major ms | 4.3% | +0.3% | +0.1 |
| railsbench yjit | wall ms/itr | 2.8% | -1.3% | -0.7 |
| railsbench yjit | GC ms/itr | 9.8% | -8.7% | -1.2 |
| railsbench yjit | wall-GC ms/itr | 2.5% | -1.0% | -0.6 |
| railsbench yjit | minor/itr | 6.8% | +10.8% | +2.2 |
| railsbench yjit | major/itr | 154.9% | -100.0% | -0.9 |
| railsbench yjit | ms/minor (prof) | 9.1% | -14.8% | -2.3 |
| railsbench yjit | mark ms/minor | 10.4% | -13.0% | -1.8 |
| railsbench yjit | median mark ms/minor | 11.8% | -15.5% | -1.9 |
| railsbench yjit | probe minor ms | 5.6% | +3.4% | +0.9 |
| railsbench yjit | probe major ms | 1.8% | +14.4% | +11.4 |
| railsbench zjit | wall ms/itr | 1.4% | -0.3% | -0.3 |
| railsbench zjit | GC ms/itr | 6.6% | -3.8% | -0.8 |
| railsbench zjit | wall-GC ms/itr | 1.4% | -0.2% | -0.1 |
| railsbench zjit | minor/itr | 2.4% | +20.2% | +12.0 |
| railsbench zjit | major/itr | NaN% | +NaN% | – |
| railsbench zjit | ms/minor (prof) | 5.9% | -20.3% | -4.8 |
| railsbench zjit | mark ms/minor | 4.7% | -54.1% | -16.3 |
| railsbench zjit | median mark ms/minor | 5.6% | -56.3% | -14.2 |
| railsbench zjit | probe minor ms | 6.0% | -20.8% | -4.9 |
| railsbench zjit | probe major ms | 8.6% | -1.7% | -0.3 |
| shipit interp | wall ms/itr | 4.0% | +0.5% | +0.2 |
| shipit interp | GC ms/itr | 6.7% | -1.3% | -0.3 |
| shipit interp | wall-GC ms/itr | 3.9% | +0.6% | +0.2 |
| shipit interp | minor/itr | 6.8% | +1.3% | +0.3 |
| shipit interp | major/itr | 21.9% | -6.7% | -0.4 |
| shipit interp | ms/minor (prof) | 9.0% | -0.6% | -0.1 |
| shipit interp | ms/major (prof) | 23.3% | -20.3% | -1.2 |
| shipit interp | mark ms/minor | 11.1% | +0.3% | +0.0 |
| shipit interp | mark ms/major | 5.4% | +0.4% | +0.1 |
| shipit interp | median mark ms/minor | 9.7% | +0.6% | +0.1 |
| shipit interp | median mark ms/major | 7.9% | -0.8% | -0.1 |
| shipit interp | fit ms/minor | 11.7% | +0.5% | +0.1 |
| shipit interp | fit ms/major | 9.9% | -6.0% | -0.9 |
| shipit interp | probe minor ms | 5.6% | +0.3% | +0.1 |
| shipit interp | probe major ms | 18.6% | -11.8% | -0.9 |
| shipit yjit | wall ms/itr | 4.8% | +0.5% | +0.2 |
| shipit yjit | GC ms/itr | 10.6% | +1.5% | +0.2 |
| shipit yjit | wall-GC ms/itr | 4.4% | +0.5% | +0.1 |
| shipit yjit | minor/itr | 3.1% | +2.2% | +1.0 |
| shipit yjit | major/itr | 14.4% | +5.9% | +0.6 |
| shipit yjit | ms/minor (prof) | 12.3% | -0.9% | -0.1 |
| shipit yjit | ms/major (prof) | 11.5% | -18.1% | -2.2 |
| shipit yjit | mark ms/minor | 14.0% | -0.2% | -0.0 |
| shipit yjit | mark ms/major | 1.8% | -6.3% | -4.9 |
| shipit yjit | median mark ms/minor | 15.6% | -1.1% | -0.1 |
| shipit yjit | median mark ms/major | 2.6% | -0.9% | -0.5 |
| shipit yjit | fit ms/minor | 13.6% | -0.0% | -0.0 |
| shipit yjit | fit ms/major | 3.9% | -8.7% | -3.2 |
| shipit yjit | probe minor ms | 5.6% | -2.0% | -0.5 |
| shipit yjit | probe major ms | 17.1% | -4.1% | -0.3 |
| shipit zjit | wall ms/itr | 4.0% | +0.9% | +0.3 |
| shipit zjit | GC ms/itr | 8.8% | -7.6% | -1.2 |
| shipit zjit | wall-GC ms/itr | 3.9% | +1.5% | +0.5 |
| shipit zjit | minor/itr | 2.8% | +5.1% | +2.6 |
| shipit zjit | major/itr | 18.8% | -7.7% | -0.6 |
| shipit zjit | ms/minor (prof) | 11.3% | -12.8% | -1.6 |
| shipit zjit | ms/major (prof) | 10.1% | -9.9% | -1.4 |
| shipit zjit | mark ms/minor | 10.9% | -28.2% | -3.7 |
| shipit zjit | mark ms/major | 5.5% | +1.2% | +0.3 |
| shipit zjit | median mark ms/minor | 10.9% | -29.1% | -3.8 |
| shipit zjit | median mark ms/major | 2.9% | +5.9% | +2.9 |
| shipit zjit | fit ms/minor | 11.1% | -13.5% | -1.7 |
| shipit zjit | fit ms/major | 6.8% | +1.1% | +0.2 |
| shipit zjit | probe minor ms | 15.2% | -26.8% | -2.5 |
| shipit zjit | probe major ms | 14.4% | -15.5% | -1.5 |
