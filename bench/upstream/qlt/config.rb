# frozen_string_literal: true

# Measurement-only query log tag settings. Each census copy's
# config/environments/production.rb gets, as the last line of its configure block:
#   eval(File.read(ENV["QLT_CONFIG"]), binding, ENV["QLT_CONFIG"]) if ENV["QLT_CONFIG"]
# QLT_TAGS=none|default|request_id  QLT_PS=on|off  QLT_CACHE=0|1
tags = ENV.fetch("QLT_TAGS")
config.active_record.query_log_tags_enabled = tags != "none"
config.active_record.cache_query_log_tags = ENV.fetch("QLT_CACHE", "0") == "1"
config.active_record.disable_prepared_statements = ENV.fetch("QLT_PS") == "off"
default = [:application, :controller, :action, :job]
wanted = case tags
         when "none" then nil
         when "default" then default
         when "request_id" then default + [{ request_id: ->(context) { context[:controller]&.request&.request_id } }]
         else raise "QLT_TAGS=#{tags}"
end
# Runs before Active Record's own after_initialize hook, which installs the tags.
config.after_initialize { config.active_record.query_log_tags = wanted } if wanted
