# Share of samples whose stack contains a frame of each category (inclusive), per profile.
CATEGORIES = {
  "save/destroy (persistence)" => /\AActiveRecord::(Persistence|Transactions|Validations|Callbacks)#(save!?|destroy!?|update!?|create_or_update|_create_record|_update_record)\z/,
  "validations" => /\AActive(Model|Record)::Validations#(valid\?|run_validations!)\z/,
  "save/commit callbacks" => /\AActiveRecord::(Callbacks#(create_or_update|_create_record|_update_record|destroy)|Transactions#(committed!|_run_commit_callbacks))\z|ActiveRecord::ConnectionAdapters::TransactionManager#commit_transaction|run_commit_callbacks/,
  "transaction blocks" => /\AActiveRecord::(ConnectionAdapters::DatabaseStatements#transaction|Transactions#with_transaction_returning_status)\z/,
  "INSERT/UPDATE/DELETE build+exec" => /\AActiveRecord::(Persistence::ClassMethods#_(insert|update|delete)_record|ConnectionAdapters::DatabaseStatements#(insert|update|delete|exec_insert|exec_update|exec_delete))\z|\AArel::(InsertManager|UpdateManager|DeleteManager)|ActiveRecord::InsertAll/,
  "Turbo broadcasts (render + cable/queue)" => /\ATurbo::Broadcastable#broadcast|\ATurbo::Streams::Broadcasts#broadcast/,
  "Solid Cable insert" => /\ASolidCable::Message\.broadcast\z/,
  "Solid Queue enqueue" => /\ASolidQueue::Job\.enqueue|ActiveJob::Enqueuing#enqueue\z/,
  "CSRF check" => /\AActionController::RequestForgeryProtection#verify_authenticity_token\z/,
  "params parsing (POST body)" => /\AActionDispatch::Request#POST\z|\ARack::Request::Helpers#POST\z/,
  "flash/redirect" => /\AActionController::Redirecting#redirect_to\z/,
  "SELECT (find/load)" => /\AActiveRecord::Relation#(load|exec_queries)\z|\AActiveRecord::Core::ClassMethods#find\z/,
  "view rendering" => /\AActionView::Template#render\z/,
}.freeze

ARGV.each do |path|
  profile = Marshal.load(File.binread(path))
  frames = profile[:frames].transform_values { _1[:name] }
  raw = profile[:raw]
  totals = Hash.new(0)
  samples = 0
  i = 0
  while i < raw.size
    len = raw[i]
    stack = raw[i + 1, len]
    count = raw[i + 1 + len]
    i += len + 2
    samples += count
    names = stack.map { frames[_1] }
    hit = CATEGORIES.select { |cat, re| names.any? { re.match?(_1.to_s) } }.keys
    hit.each { totals[_1] += count }
    totals["ANY write path (first 8 rows)"] += count if (hit & CATEGORIES.keys.first(8)).any?
  end
  puts "#{File.basename(path)}: #{samples} samples"
  (CATEGORIES.keys + ["ANY write path (first 8 rows)"]).each { |cat| puts format("  %-42s %5.1f%%", cat, 100.0 * totals[cat] / samples) }
end
