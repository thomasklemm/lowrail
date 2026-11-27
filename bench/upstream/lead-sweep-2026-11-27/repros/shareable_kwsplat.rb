# shareable_constant_value: experimental_everything
# A Hash literal with a double splat and a static key in a shareable constant.
H = { b: 2 }
X = { **H, a: 1 }
p X, Ractor.shareable?(X)
