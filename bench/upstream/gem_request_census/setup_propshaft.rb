# Setup for ir.sh: a Propshaft load path over PROPSHAFT_TREE's subdirectories
# (Mastodon's app/javascript/images and material-icons, 435 files).
require "active_support/all"
require "action_dispatch/http/mime_type"
module Propshaft; end
require "propshaft/load_path"
$lp = Propshaft::LoadPath.new(Dir[File.join(ENV.fetch("PROPSHAFT_TREE"), "*")].sort, compilers: nil)
def reload_assets = ($lp.send(:clear_cache); $lp.send(:assets_by_path))
