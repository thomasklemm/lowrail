require "uri"; require "cgi/escape"
def alt_escape(s)
  r = CGI.escape(s.to_s).force_encoding(Encoding::US_ASCII)
  r.gsub!("%2A", "*") if r.include?("%2A")
  r.gsub!("~", "%7E") if r.include?("~")
  r
end
COOKIE = "xKq3r9vB0lQm2pZ8nY4tW6sE1uI7oA5d+H/jF3gC9kL0bN2mV4xZ8cQ1wR6tY5uP3iO7aS9dG2hJ4kL6zX8cV0bN==--a1B2c3D4e5F6g7H8i9J0kL1mN2oP3qR4sT5uV6wX7yZ8a9B0c1D2e3F4g5H6i7J8k9L0m1N2o3P4q5R6s7T8u9V0w1X2y3Z4==--0123456789abcdef0123456789abcdef01234567"
