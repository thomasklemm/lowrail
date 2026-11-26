# lowrail-profile changelog

## 0.1.1 (unreleased)

* An engine profiled in place, whose own directory is both the app root and a path gem, keeps the files under a
  directory named `gems` (such as `app/views/gems/index.html.erb`) as app lines, like its other files; 0.1 ranked them
  as the engine gem's. So does a dummy app below an engine kept in a `gems/` directory. A path gem kept inside the app
  (`gems/`, `vendor/gems/`) is still ranked as that gem.
* Tests: `QUIT` reaches the command under `--timeout`, a signal that comes before the command is started reaches it
  once it runs, and `profile_test.rb` is split into `profile_test.rb`, `profile_record_test.rb` and
  `profile_cli_test.rb`.

## 0.1.0 (not published)

Built from `644c99e4` as `0.1.0.rc1`.
