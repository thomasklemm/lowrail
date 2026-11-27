base = (1..18).to_h { ["HTTP_X_HEADER_NUMBER_#{_1}", "value"] }
cfg = (1..28).to_h { ["action_dispatch.some_config_key_#{_1}".freeze, Object.new] }
$op = case ENV["CASE"]
when "dup" then -> { base.dup }
when "merge" then -> { base.dup.merge!(cfg) }
when "rev" then -> { cfg.merge(base) }
end
$op = case ENV["CASE"]
when "presized" then -> { h = Hash.new(capacity: 64); h.merge!(base); h.merge!(cfg) }
when "twomerge" then -> { h = {}; h.merge!(base); h.merge!(cfg) }
end if %w[presized twomerge].include?(ENV["CASE"])
