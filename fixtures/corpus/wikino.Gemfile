# Dependency-only wrapper; leave the pinned app tree unchanged.
eval_gemfile File.expand_path("../../.corpus/wikino/rails/Gemfile", __dir__)
ruby "4.0.7"
gem "unicode-emoji", "4.3.0"
gem "rqrcode_core", "2.1.0"
@dependencies.reject! { |dependency| dependency.name == "rqrcode" }
gem "rqrcode", "3.1.1"
gem "ffi", "1.17.4"
@dependencies.reject! { |dependency| dependency.name == "pg" }
gem "pg", "1.6.3"
@dependencies.reject! { |dependency| dependency.name == "vcr" }
group :test do
  gem "vcr", "6.4.0"
end
