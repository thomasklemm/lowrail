# frozen_string_literal: true

module Lowrail
  # Audited Rails releases: certified source files and whole-gem inventories (docs/rails-pins.md). A release is
  # added only after re-auditing the certified methods in every file or gem whose pin changed; others refuse.
  module RailsPins
    RELEASES = {
      "8.1.4" => {
        "files" => {
          "action_view/helpers/tag_helper.rb" => "7bca8efe1bd2421c5e65671aabdf35c97831ab0cb2cbdcdb5dd317d22aa16c31",
          "action_view/helpers/url_helper.rb" => "ebdccd38cf87f6f83d758ba424df61d72c8033629f0e70a8ddb21b7b8ed086ee",
          "action_controller/metal.rb" => "c8559e0a0c9e40ac9a29a4ae01de7c9aab7c438e1af751368e10e3802024cb36",
          "active_support/core_ext/object/blank.rb" => "203eefc5b094f4a0f5bf68b4c34198891127f52ed7825e146c2fa089a46f8ec7",
          "active_support/core_ext/erb/util.rb" => "1e348e9c8840caa9942691a290e0424c1755256b03a90eb96a094bbf86ff368f",
          "active_support/core_ext/string/output_safety.rb" => "8d8c461dbcd14db6b894671a1ec53b03c39637a67c27222e7d22bbe3c2f411d6"
        }.freeze,
        "gems" => {
          "actionview" => "b7135e378dc024f779abcf81b6f002e4ffc840fd691a77ea8278803ceddd35fd",
          "actionpack" => "aa7b3edafe53f19d4a54737b1dc5f84e49af40e08fc694f07bd28fcc7d609844",
          "activemodel" => "2927864a4658fc82c0d2aac115b7d72521739306ac8b2e2a3ee520d9f3edb39b",
          "activerecord" => "71e11e0f71594fdfbf318dc2b289c4f6da5f1e5b8daae2a8cc36ff9e5e7d3d6c",
          "activesupport" => "7b52dc2e11d86c2abe911faf31882990cd783d49e3c5bc54c554130cdcc1a0f7"
        }.freeze
      }.freeze,
      "8.1.4.1" => {
        "files" => {
          "action_view/helpers/tag_helper.rb" => "237a725fd719c0ba0c8330a60979ef15eb77733ccf725fe3717cce2698d50673",
          "action_view/helpers/url_helper.rb" => "ebdccd38cf87f6f83d758ba424df61d72c8033629f0e70a8ddb21b7b8ed086ee",
          "action_controller/metal.rb" => "c8559e0a0c9e40ac9a29a4ae01de7c9aab7c438e1af751368e10e3802024cb36",
          "active_support/core_ext/object/blank.rb" => "203eefc5b094f4a0f5bf68b4c34198891127f52ed7825e146c2fa089a46f8ec7",
          "active_support/core_ext/erb/util.rb" => "1e348e9c8840caa9942691a290e0424c1755256b03a90eb96a094bbf86ff368f",
          "active_support/core_ext/string/output_safety.rb" => "8d8c461dbcd14db6b894671a1ec53b03c39637a67c27222e7d22bbe3c2f411d6"
        }.freeze,
        "gems" => {
          "actionview" => "af456c211b19686cd832f934370795ccf288e66f3571fa847570bbf36c8afe59",
          "actionpack" => "a8fe1909000317fc4659b1feaeba914203e8a0580bd1a4e0c82cc8b0fc8deb60",
          "activemodel" => "95b64a7fe85cb79cccf58f7a7861ba1cb06e80dcac9f9df04099bcac1fe205b6",
          "activerecord" => "4393eb4811f3dc2e996544761b157886770d6a78e8167072f8f5e06d689ae5d8",
          "activesupport" => "7ac516ca5e0fe83c67a41f4b0c39d40077a0d314eee5e61ae34f8d935f1180b4"
        }.freeze
      }.freeze
    }.freeze

    def self.release = RELEASES[Rails.version]
  end
end
