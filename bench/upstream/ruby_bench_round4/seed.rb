# Control preload (RUBYOPT=-r.../seed.rb): seeds Ruby's default RNG before the
# benchmark loads, so Kernel#rand, Array#sample/shuffle and Random.alphanumeric
# give the same sequence in every process. OpenSSL/SecureRandom stay unseeded.
srand(Integer(ENV.fetch("SEED", "1234")))
