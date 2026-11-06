# Write-path hot spots in a StackProf raw dump (from prof.rb): share of all samples
# whose stack contains each frame, among samples inside a write action, plus the top
# self frames inside write actions.
WRITE = /\A(ArticlesController#(create|update|destroy)|CommentsController#(create|destroy))\z/
CANDIDATES = {
  "write actions (all)" => WRITE,
  "validations (valid?)" => /\AActiveRecord::Validations#valid\?\z/,
  "transaction wrapper (with_transaction_returning_status)" => /\AActiveRecord::Transactions#with_transaction_returning_status\z/,
  "savepoint begin (materialize/create_savepoint)" => /SavepointTransaction#materialize!|#create_savepoint\z/,
  "savepoint release + commit (commit_transaction)" => /TransactionManager#commit_transaction\z/,
  "commit callbacks (committed!)" => /\AActiveRecord::Transactions#committed!\z/,
  "save callbacks (_run_save_callbacks)" => /#_run_save_callbacks\z/,
  "INSERT (_insert_record)" => /\AActiveRecord::Persistence::ClassMethods#_insert_record\z/,
  "UPDATE (_update_record)" => /\AActiveRecord::Persistence::ClassMethods#_update_record\z/,
  "DELETE (_delete_record)" => /\AActiveRecord::Persistence::ClassMethods#_delete_record\z/,
  "dependent: :destroy (has_many destroy)" => /HasManyAssociation#delete_records|Associations::Builder::HasMany\.define_callbacks|handle_dependency/,
  "Turbo broadcast render (render_format/ApplicationController.render)" => /\ATurbo::Streams::Broadcasts#render_format\z|\ATurbo::Streams::ActionHelper#turbo_stream_action_tag\z/,
  "Turbo broadcast (broadcast_action_to, sync)" => /\ATurbo::Streams::Broadcasts#broadcast_action_to\z/,
  "Turbo *_later (enqueue)" => /\ATurbo::Streams::Broadcasts#broadcast_action_later_to\z/,
  "Solid Cable insert (Message.broadcast)" => /\ASolidCable::Message\.broadcast\z/,
  "Active Job enqueue (ActiveJob::Enqueuing#enqueue)" => /\AActiveJob::Enqueuing#enqueue\z/,
  "Solid Queue insert (Job.enqueue)" => /\ASolidQueue::Job\.enqueue\z/,
  "job serialization (ActiveJob::Core#serialize)" => /\AActiveJob::Core#serialize\z/,
  "strong params (params.expect)" => /\AActionController::Parameters#expect\z/,
  "CSRF verify" => /\AActionController::RequestForgeryProtection#verify_authenticity_token\z/,
  "redirect_to" => /\AActionController::Redirecting#redirect_to\z/,
  "SQL execute (raw_execute)" => /\AActiveRecord::ConnectionAdapters::DatabaseStatements#raw_execute\z/,
}.freeze

profile = Marshal.load(File.binread(ARGV.fetch(0)))
frames = profile[:frames].transform_values { _1[:name].to_s }
raw = profile[:raw]
incl = Hash.new(0)
self_w = Hash.new(0)
total = write = 0
i = 0
while i < raw.size
  len = raw[i]; stack = raw[i + 1, len]; count = raw[i + 1 + len]; i += len + 2
  total += count
  names = stack.map { frames[_1] }
  next unless names.any? { WRITE.match?(_1) }
  write += count
  self_w[names.last] += count # stackprof raw stacks are root-first; last is the leaf
  CANDIDATES.each { |k, re| incl[k] += count if names.any? { re.match?(_1) } }
end
puts "samples #{total}, inside write actions #{write} (#{(100.0 * write / total).round(1)}%)"
puts "inclusive, % of all samples:"
CANDIDATES.each_key { |k| puts format("  %-68s %5.1f%%", k, 100.0 * incl[k] / total) }
puts "top self frames inside write actions, % of all samples:"
self_w.sort_by { -_2 }.first(25).each { |n, c| puts format("  %-90s %5.2f%%", n[0, 90], 100.0 * c / total) }
