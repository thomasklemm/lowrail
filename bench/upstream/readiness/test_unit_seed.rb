# frozen_string_literal: true

# test-unit has no seed option; its --order=random draws from Kernel#rand, so seeding that fixes the order.
srand(Integer(ENV["SEED"])) if ENV["SEED"]
