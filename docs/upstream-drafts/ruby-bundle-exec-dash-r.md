# Draft: bugs.ruby-lang.org, Bug report (not posted; Thomas posts it)

* Tracker: Bug
* Subject: `bundle exec ruby -rGEM` loads the newest installed GEM instead of the locked one
* ruby -v: ruby 4.1.0dev master d2a6a9d9fa
* Backport: none (4.0 is not affected)

---

On master, a gem named with `-r` under `bundle exec` is activated before Bundler is set up, so it comes from the newest installed version instead of the lockfile. Ruby 4.0 uses the locked version.

```sh
gem install rainbow -v 3.1.1
mkdir repro && cd repro
printf 'source "https://rubygems.org"\ngem "rainbow", "3.0.0"\n' > Gemfile
BUNDLE_PATH=vendor bundle install
BUNDLE_PATH=vendor bundle exec ruby -rrainbow -e 'puts Gem.loaded_specs["rainbow"].version'
```

Ruby 4.0.9 prints `3.0.0`. Master raises:

```
Gem::LoadError: You have already activated rainbow 3.1.1, but your Gemfile requires rainbow 3.0.0. Prepending `bundle exec` to your command may solve this.
```

`bundle exec` sets `BUNDLER_SETUP` and adds `-rbundler/setup` to `RUBYOPT`. Until now, `rubygems.rb` required `ENV["BUNDLER_SETUP"]` while it loaded, so Bundler was set up before the command-line `-r` options ran. Since [c3c0e280d0](https://github.com/ruby/ruby/commit/c3c0e280d0) (Bug #22123), `gem_prelude.rb` removes `BUNDLER_SETUP` before loading RubyGems whenever error_highlight, did_you_mean and syntax_suggest are autoloaded, which is the default since [cadf8e7933](https://github.com/ruby/ruby/commit/cadf8e7933) (Feature #21951). Its comment says Bundler is then set up by `RUBYOPT=-rbundler/setup` after boot, but command-line `-r` options run before `RUBYOPT`'s, so `-rrainbow` activates 3.1.1 first.

The same order also stops `bundle exec ruby -ropenssl` from printing the bundled gems warning. ruby/ruby#18400 changed `spec/bundled_gems_spec.rb` to pass `-rbundler/setup` explicitly instead.

Bug #22123 needed the skip only outside the main box. Would it work to keep consuming `BUNDLER_SETUP` in the main box, so that only the box condition remains? The error decorator gems would still be loaded lazily.
