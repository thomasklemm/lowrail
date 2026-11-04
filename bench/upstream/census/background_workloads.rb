# frozen_string_literal: true

# Background census workloads (docs/upstream/background-census.md): Active Job
# enqueue and perform, Action Mailer delivery, Active Storage reads and URLs,
# and Action Cable broadcasts and subscriptions, in the census apps. Loaded by
# harness.rb when CENSUS_SET=background; same Op contract as the request
# workloads: each op does one ordinary operation and raises unless it succeeded,
# and state a write op adds is removed when the workloads are built.
#
# External controls, the same for every app, on top of the harness's (:test
# queue adapter, :test delivery):
# * Action Cable publishes through an inline adapter that counts broadcasts and
#   delivers to in-process subscribers on the calling thread (production apps
#   publish to Redis or a database), so a broadcast's own work is measured and
#   nothing runs on other threads.
# * Subscriptions run through ActionCable::Server::Socket with a stand-in for
#   the client WebSocket that keeps the last frame it was sent.
# * Test delivery does not encode the message; SMTP and every other real
#   deliverer do, so "deliver_now" ops encode the delivered message afterwards.
module BackgroundWorkloads
  module_function

  if defined?(ActionCable)
    # Inline pub/sub that counts what was published (the check for broadcast ops).
    class CensusCable < ActionCable::SubscriptionAdapter::Inline
      attr_accessor :broadcasts

      def initialize(*)
        super
        @broadcasts = 0
      end

      def broadcast(channel, payload)
        @broadcasts += 1
        super
      end
    end
  end

  # The client end of a WebSocket: open, and keeps the last frame.
  class ClientStandIn
    attr_reader :last, :frames

    def initialize
      @frames = 0
    end

    def possible? = true
    def alive? = true
    def protocol = "actioncable-v1-json"
    def close(*) = nil

    def transmit(data)
      @frames += 1
      @last = data
    end
  end

  def boot(c)
    return if @booted
    @booted = true
    ActionCable.server.instance_variable_set(:@pubsub, CensusCable.new(ActionCable.server)) if defined?(ActionCable)
  end

  def cable = ActionCable.server.pubsub

  def op(c, name, kind, &block) = c::Op.new(name, kind, block)

  ID = ->(&b) { b.call }
  TURBO = { "HTTP_ACCEPT" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze

  def url_helpers = Rails.application.routes.url_helpers

  # -- Active Job ------------------------------------------------------------

  # Perform from the job's JSON, as a queue worker does (Sidekiq, Solid Queue
  # and Resque store the serialized job as JSON and execute the parsed Hash).
  def perform_job_op(c, name, payload)
    json = JSON.generate(payload)
    op(c, name, :job) { ActiveJob::Base.execute(JSON.parse(json)) }
  end

  # The enqueue itself (serialize through the test adapter) and the perform of
  # each job class it enqueued (deserialize, callbacks, perform).
  def job_ops(c, label, perform: true, &enqueue)
    jobs = c.jobs_from(&enqueue)
    raise "#{label}: nothing enqueued" if jobs.empty?
    count = jobs.size
    ops = [op(c, "enqueue #{label}", :enqueue) {
      enqueue.call
      raise "#{label}: enqueued #{c.captured_jobs.size}, expected #{count}" unless c.captured_jobs.size == count
    }]
    jobs.uniq { _1["job_class"] }.each { ops << perform_job_op(c, "perform #{_1["job_class"]}", _1) } if perform
    ops
  end

  # The jobs an app action enqueues (a request, a model callback), each
  # enqueued again with the same class and arguments (deserialized once,
  # outside the op), and performed from its serialized form. `around` wraps
  # the enqueue in the context the app enqueues it in (Current attributes).
  def replay_job_ops(c, jobs, around: ID, skip: [])
    jobs.uniq { _1["job_class"] }.reject { skip.include?(_1["job_class"]) }.flat_map do |payload|
      klass = payload["job_class"].constantize
      args = ActiveJob::Arguments.deserialize(payload["arguments"])
      configured = payload["scheduled_at"] ? klass.set(wait: 5.minutes) : klass
      [op(c, "enqueue #{klass.name}", :enqueue) {
        around.call { configured.perform_later(*args) }
        raise "#{klass}: enqueued #{c.captured_jobs.size}" unless c.captured_jobs.size == 1
      }, perform_job_op(c, "perform #{klass.name}", payload)]
    end
  end

  # The perform ops of the request census's workloads (the jobs its write
  # requests enqueue, Active Job or native Sidekiq), for apps whose background
  # work is mostly jobs the census already captures.
  module JobRecorder
    attr_accessor :recorded_jobs

    def jobs_from(&)
      super.tap { recorded_jobs&.concat(_1) }
    end
  end

  # The payloads those request workloads' jobs_from captured.
  def request_jobs(c, app)
    c.singleton_class.prepend(JobRecorder) unless c.singleton_class < JobRecorder
    c.recorded_jobs = []
    request_job_ops(c, app)
    c.recorded_jobs
  ensure
    c.recorded_jobs = nil
  end

  def request_job_ops(c, app)
    load File.join(__dir__, "../census_4_workloads.rb")
    load File.join(__dir__, "pg_workloads.rb")
    load File.join(__dir__, "inertia_chatwoot_workloads.rb")
    Census4Workloads.public_send(app, c).select { _1.kind == :job }
  end

  # -- Action Mailer ---------------------------------------------------------

  # deliver_now (render, test delivery, then encode as a real deliverer would),
  # deliver_later (MailDeliveryJob enqueue) and that job's perform.
  def mail_ops(c, label, later: true, around: ID, later_options: {}, &build)
    deliver = op(c, "deliver_now #{label}", :mailer) {
      around.call { build.call.deliver_now }
      mail = ActionMailer::Base.deliveries.last or raise "#{label}: nothing delivered"
      raise "#{label}: empty encoding" if mail.encoded.empty?
    }
    return [deliver] unless later
    enqueue, *performs = job_ops(c, "deliver_later #{label}") { around.call { build.call.deliver_later(**later_options) } }
    [deliver, enqueue, *performs.map { |job_op| op(c, "perform deliver_later #{label}", :job) {
      job_op.call.call
      raise "#{label}: nothing delivered" if ActionMailer::Base.deliveries.empty?
    } }]
  end

  # -- Active Storage --------------------------------------------------------

  # A blob from a fixed census file, attached once to `record.name`; reused
  # across runs (no state accumulates).
  def ensure_attached(record, name, path, content_type)
    attached = record.public_send(name)
    return record if attached.attached? && attached.filename.to_s == File.basename(path)
    blob = ActiveStorage::Blob.create_and_upload!(io: File.open(path, "rb"), filename: File.basename(path),
      content_type: content_type, identify: false)
    blob.analyze unless blob.analyzed?
    attached.attach(blob)
    record.save! if record.changed?
    record
  end

  def fixture_file(name) = File.join(RailsCensus::ROOT, "fixtures/background-census", name)

  # Reads and URLs of one attachment: the attachment and blob loaded from a
  # fresh record, the blob path and URL helpers, a variant path, and the
  # redirect and Disk service requests a browser makes for it.
  def storage_ops(c, label, model, id, name, variant: nil, client: c::Client.new, requests: true, url_options: {})
    record = model.find(id)
    attached = record.public_send(name)
    raise "#{label}: not attached" unless attached.attached?
    attached.blob # loaded once, as after a view's first read
    ops = [
      op(c, "AS read #{label}", :storage) {
        a = model.find(id).public_send(name)
        raise "#{label}: not attached" unless a.attached?
        raise "#{label}: no filename" if a.filename.to_s.empty?
        a.content_type && a.byte_size && a.metadata
      },
      op(c, "AS rails_blob_path #{label}", :storage) { url_helpers.rails_blob_path(attached, only_path: true, **url_options) },
      op(c, "AS url_for #{label}", :storage) { url_helpers.polymorphic_url(attached, **url_options) },
    ]
    if variant
      ops << op(c, "AS variant path #{label}", :storage) {
        url_helpers.rails_representation_path(attached.variant(variant), only_path: true, **url_options)
      }
    end
    if requests
      path = url_helpers.rails_blob_path(attached, only_path: true, **url_options)
      first = client.get(path, expect: [200, 302])
      if first.status == 200 # proxy mode (resolve_model_to_route = :rails_storage_proxy)
        ops << op(c, "AS GET blob proxy #{label}", :storage) {
          raise "#{label}: empty file" if client.get(path, expect: 200).body.empty?
        }
      else
        ops << op(c, "AS GET blob redirect #{label}", :storage) { client.get(path, expect: 302) }
        fresh = -> { URI(client.get(path, expect: 302).headers["location"]).request_uri }
        service = fresh.call
        ops << op(c, "AS GET disk file #{label}", :storage) {
          response = client.get(service, expect: [200, 404])
          # Service URLs expire (5 minutes); a long Callgrind window outlives one.
          response = client.get(service = fresh.call, expect: 200) if response.status == 404
          raise "#{label}: empty file" if response.body.empty?
        }
      end
      ops << op(c, "AS download #{label}", :storage) { raise "#{label}: empty download" if attached.download.empty? }
    end
    ops
  end

  # -- Action Cable ----------------------------------------------------------

  def cable_env(cookies, extra = {})
    extra.merge Rack::MockRequest.env_for("https://localhost/cable", "HTTP_HOST" => "localhost", "HTTPS" => "on",
      "HTTP_ORIGIN" => "https://localhost", "HTTP_COOKIE" => cookies.map { |k, v| "#{k}=#{v}" }.join("; "),
      "HTTP_USER_AGENT" => RailsMainCensus4::UA, "REMOTE_ADDR" => "127.0.0.1")
  end

  # An opened connection (the app's Connection#connect and the welcome frame).
  def open_socket(env)
    socket = ActionCable::Server::Socket.new(ActionCable.server, env.dup)
    client = ClientStandIn.new
    socket.instance_variable_set(:@websocket, client)
    socket.send(:handle_open)
    raise "cable connection rejected: #{client.last}" unless client.last.to_s.include?("welcome")
    [socket, client]
  end

  def close_socket(socket) = socket.send(:handle_close)

  def command(socket, command, identifier, data = nil)
    message = { "command" => command, "identifier" => identifier }
    message["data"] = JSON.generate(data) if data
    socket.dispatch_websocket_message(JSON.generate(message))
  end

  # Connect, subscribe to each channel, unsubscribe and disconnect: what a page
  # load with Action Cable subscriptions costs the server.
  def subscribe_op(c, label, cookies, identifiers, env: {})
    identifiers = identifiers.map { JSON.generate(_1) }
    env = cable_env(cookies, env)
    op(c, "cable subscribe #{label}", :cable) {
      socket, client = open_socket(env)
      identifiers.each do |identifier|
        command(socket, "subscribe", identifier)
        raise "#{label}: #{identifier} not confirmed: #{client.last}" unless client.last.include?("confirm_subscription")
      end
      identifiers.each { command(socket, "unsubscribe", _1) }
      close_socket(socket)
    }
  end

  # One client message to a subscribed channel's action (the socket stays open).
  def perform_op(c, label, cookies, identifier, data, broadcasts: 1, env: {})
    identifier = JSON.generate(identifier)
    socket, client = open_socket(cable_env(cookies, env))
    command(socket, "subscribe", identifier)
    raise "#{label}: not confirmed: #{client.last}" unless client.last.include?("confirm_subscription")
    op(c, "cable perform #{label}", :cable) {
      before = cable.broadcasts
      command(socket, "message", identifier, data)
      raise "#{label}: #{cable.broadcasts - before} broadcasts" unless cable.broadcasts - before == broadcasts
    }
  end

  def broadcast_op(c, label, min: 1, &block)
    op(c, "cable broadcast #{label}", :cable) {
      before = cable.broadcasts
      block.call
      raise "#{label}: #{cable.broadcasts - before} broadcasts" if cable.broadcasts - before < min
    }
  end

  def signed_cookie(c, name, value) = c.signed_cookie(name, value)

  # -- Apps -----------------------------------------------------------------

  def campfire(c)
    boot(c)
    # External control: web push goes to a thread pool that posts to push
    # services; the payload is built, the HTTP posts are not made.
    Rails.configuration.x.web_push_pool = Struct.new(:queued) { def queue(*) = (self.queued += 1); def shutdown = nil }.new(0)
    user = User.find_by!(email_address: "david@37signals.com")
    login = user.sessions.start!(user_agent: c::UA, ip_address: "127.0.0.1")
    cookie_name, cookie_value = c.signed_cookie(:session_token, login.token)
    cookies = { cookie_name => cookie_value }
    client = c::Client.new
    client.cookie(cookie_name, cookie_value)
    room = Room.find_by!(name: "Designers")
    room.messages.where(creator: user).joins(:rich_text_body)
      .where("action_text_rich_texts.body LIKE '%Census bg message%'").find_each(&:destroy)
    message = room.messages.create!(creator: user, body: "Census bg message")
    ensure_attached(user, :avatar, fixture_file("avatar.png"), "image/png")
    attachment_message = room.messages.joins(:attachment_attachment).where(creator: user).first ||
      room.messages.create!(creator: user, body: "Census bg attachment")
    ensure_attached(attachment_message, :attachment, fixture_file("photo.jpg"), "image/jpeg")
    room_id = { "channel" => "RoomChannel", "room_id" => room.id }
    [
      *job_ops(c, "Room::PushMessageJob") { Room::PushMessageJob.perform_later(room, message) },
      *job_ops(c, "Message::BroadcastUnreadRoomJob") { Message::BroadcastUnreadRoomJob.perform_later(message) },
      broadcast_op(c, "Message#broadcast_create (Turbo append)") { message.broadcast_create },
      broadcast_op(c, "Message#broadcast_unread_room") { message.broadcast_unread_room },
      broadcast_op(c, "attachment message broadcast_create") { attachment_message.broadcast_create },
      subscribe_op(c, "room page (Room, Presence, Typing, Unread, Read)", cookies, [
        room_id, room_id.merge("channel" => "PresenceChannel"), room_id.merge("channel" => "TypingNotificationsChannel"),
        { "channel" => "UnreadRoomsChannel" }, { "channel" => "ReadRoomsChannel" }
      ]),
      perform_op(c, "TypingNotificationsChannel#start", cookies, room_id.merge("channel" => "TypingNotificationsChannel"),
        { "action" => "start" }),
      *storage_ops(c, "user avatar", User, user.id, :avatar, variant: :square, client: client),
      *storage_ops(c, "message attachment", Message, attachment_message.id, :attachment, variant: :thumb, client: client),
    ]
  end

  def turbo_stream(*streamables) = { "channel" => "Turbo::StreamsChannel",
    "signed_stream_name" => Turbo::StreamsChannel.signed_stream_name(streamables) }

  def writebook(c)
    boot(c)
    user = User.find_by!(email_address: "david@example.com")
    login = user.sessions.start!(user_agent: c::UA, ip_address: "127.0.0.1")
    cookie = c.signed_cookie(:session_token, login.token)
    client = c::Client.new
    client.cookie(*cookie)
    book = Book.find_by!(slug: "handbook")
    leaf = book.leaves.find_by!(title: "Welcome to The Handbook!")
    ensure_attached(book, :cover, fixture_file("photo.jpg"), "image/jpeg")
    picture_leaf = book.leaves.find_by(title: "Census picture") ||
      book.press(Picture.new(caption: "Census picture"), title: "Census picture")
    ensure_attached(picture_leaf.leafable, :image, fixture_file("photo.jpg"), "image/jpeg")
    page = book.leaves.find_by!(title: "Census edited page") # created by the request workloads' setup
    token = client.csrf("/")
    n = [0]
    update = -> {
      client.patch("/books/#{book.id}/pages/#{page.id}", headers: TURBO,
        params: { page: { body: c.flip(n, "Census body A", "Census body B") }, leaf: { title: "Census edited page" },
          authenticity_token: token })
    }
    [
      *replay_job_ops(c, c.jobs_from(&update)),
      broadcast_op(c, "Turbo broadcast_render_to being_edited") {
        Turbo::StreamsChannel.broadcast_render_to(page, :being_edited, partial: "leaves/being_edited_by",
          locals: { leaf: page, user: user })
      },
      subscribe_op(c, "leaf page (being_edited stream)", [cookie].to_h, [turbo_stream(leaf, :being_edited)]),
      *storage_ops(c, "book cover", Book, book.id, :cover, variant: { resize_to_limit: [600, 600] }, client: client),
      *storage_ops(c, "picture image", Picture, picture_leaf.leafable_id, :image, variant: :large, client: client),
    ]
  end

  def fizzy(c)
    boot(c)
    identity = Identity.find_by!(email_address: "kevin@37signals.com")
    login = identity.sessions.create!
    cookie = c.signed_cookie(:session_token, login.signed_id)
    client = c::Client.new
    client.cookie(*cookie)
    user = identity.users.find_by!(name: "Kevin")
    account = user.account
    in_account = ->(&b) { Current.set(account: account, user: user, &b) }
    board = account.boards.find_by!(name: "Writebook")
    card = in_account.call { board.cards.order(:number).second }
    in_account.call { card.comments.where(creator: user).find_each(&:destroy) }
    comment_path = "/#{account.external_account_id}/cards/#{card.number}/comments"
    create = -> { client.post(comment_path, headers: TURBO, params: { comment: { body: "Census bg comment" } }) }
    magic_link = identity.magic_links.create!
    reader = Notification.where(read_at: nil).order(:id).first!.user
    bundle = Notification::Bundle.find_by(user: reader, starts_at: Time.utc(2000)) ||
      Notification::Bundle.create!(user: reader, starts_at: Time.utc(2000), ends_at: Time.utc(2100))
    with_reader = ->(&b) { reader.in_time_zone { Current.with_account(reader.account, &b) } }
    in_account.call { ensure_attached(user, :avatar, fixture_file("avatar.png"), "image/png") }
    in_account.call { ensure_attached(card, :image, fixture_file("photo.jpg"), "image/jpeg") }
    cable = [cookie].to_h
    # Set by Fizzy's account-slug middleware from the /ACCOUNT/cable path.
    socket_env = { "fizzy.external_account_id" => account.external_account_id }
    slug = { script_name: "/#{account.external_account_id}" }
    ops = in_account.call { replay_job_ops(c, c.jobs_from(&create), around: in_account) }
    ops + [
      *mail_ops(c, "MagicLinkMailer#sign_in_instructions") { MagicLinkMailer.sign_in_instructions(magic_link) },
      # The bundle is delivered by its own job (bundle.deliver), not deliver_later.
      *mail_ops(c, "Notification::BundleMailer#notification", later: false, around: with_reader) { Notification::BundleMailer.notification(bundle) },
      broadcast_op(c, "Card#broadcast_refresh") { in_account.call { card.broadcast_refresh } },
      broadcast_op(c, "pin broadcast_replace_to") { in_account.call { card.broadcast_replace_to([user, :pins_tray], partial: "cards/display/preview", locals: { card: card }) } },
      subscribe_op(c, "card page (card, activity, board, all boards)", cable,
        [turbo_stream(card), turbo_stream(card, :activity), turbo_stream(board), turbo_stream(account, :all_boards)], env: socket_env),
      *in_account.call { storage_ops(c, "user avatar", User, user.id, :avatar, variant: :thumb, client: client, url_options: slug) },
      *in_account.call { storage_ops(c, "card image", Card, card.id, :image, variant: { resize_to_limit: [800, 800] }, client: client, url_options: slug) },
    ]
  end
  singleton_class.alias_method :fizzy_mysql, :fizzy

  # Lobsters: no Active Storage or Action Cable; its background work is mail
  # and the notification jobs its controllers enqueue.
  def lobsters(c)
    boot(c)
    reply = Comment.where(is_deleted: false).where.not(parent_comment_id: nil).order(:id).first!
    top = Comment.where(is_deleted: false, parent_comment_id: nil).order(:id).first!
    recipient = reply.parent_comment.user
    message = Message.order(:id).first!
    [
      *job_ops(c, "NotifyCommentJob") { NotifyCommentJob.perform_later(reply) },
      *job_ops(c, "NotifyMessageJob") { NotifyMessageJob.perform_later(message) },
      *mail_ops(c, "EmailReplyMailer#reply") { EmailReplyMailer.reply(reply, recipient) },
      *mail_ops(c, "EmailReplyMailer#mention") { EmailReplyMailer.mention(top, recipient) },
      *mail_ops(c, "EmailMessageMailer#notify") { EmailMessageMailer.notify(message, message.recipient) },
      *mail_ops(c, "PasswordResetMailer#password_reset_link") { PasswordResetMailer.password_reset_link(recipient, "127.0.0.1") },
    ]
  end

  # Mastodon: no Active Storage (Paperclip) or Action Cable (its own streaming
  # server). Notification mail as NotifyService sends it, the account mailers,
  # and the Sidekiq jobs a new status pushes.
  def mastodon(c)
    boot(c)
    jobs = request_job_ops(c, "mastodon")
    alice = Account.find_local!("alice")
    notifications = %w[mention follow favourite].to_h { [_1, Notification.where(account: alice, type: _1).order(:id).first!] }
    mails = notifications.flat_map do |type, notification|
      mail_ops(c, "NotificationMailer##{type}", later_options: { wait: 2.minutes }) {
        NotificationMailer.with(recipient: alice, notification: notification).public_send(type)
      }
    end
    [
      *jobs,
      *mails,
      *mail_ops(c, "UserMailer#welcome") { UserMailer.welcome(alice.user) },
      *mail_ops(c, "UserMailer#password_change") { UserMailer.password_change(alice.user) },
    ]
  end

  # A delivery an app makes itself (its own job or sender), then encoded as
  # SMTP would.
  def delivery_op(c, label, &block)
    op(c, label, :mailer) {
      block.call
      mail = ActionMailer::Base.deliveries.last or raise "#{label}: nothing delivered"
      raise "#{label}: empty encoding" if mail.encoded.empty?
    }
  end

  # Discourse: no Active Storage or Action Cable (MessageBus). Its email jobs
  # (Jobs::UserEmail and Jobs::CriticalUserEmail build a UserNotifications mail
  # and send it through Email::Sender) and the Sidekiq jobs a reply pushes.
  def discourse(c)
    boot(c)
    jobs = request_job_ops(c, "discourse")
    # A post of its own with a mention (the request workloads delete their replies).
    admin = User.find_by!(username: "census0")
    user = User.find_by!(username: "census2")
    topic = Topic.where(archetype: "regular").where("title LIKE 'Census topic%'").order(:id).first!
    post = Post.where(topic_id: topic.id).where("raw LIKE 'Census bg mention%'").first ||
      PostCreator.create!(admin, topic_id: topic.id, raw: "Census bg mention of @census2 with **bold** text")
    find = -> { Notification.find_by(user: user, notification_type: Notification.types[:mentioned], topic_id: topic.id, post_number: post.post_number) }
    mention = find.call || (PostAlerter.post_created(post) && find.call) or raise "discourse: no mention notification"
    # The token is readable only right after creation, so each setup replaces it.
    user.email_tokens.where(scope: EmailToken.scopes[:password_reset]).delete_all
    token = user.email_tokens.create!(email: user.email, scope: EmailToken.scopes[:password_reset]).token
    # Discourse sends one email per post and user, at most
    # max_emails_per_day_per_user a day, and one digest per interval; each op
    # first removes what the previous one recorded (two small writes).
    reset = -> {
      EmailLog.where(user_id: user.id).delete_all
      user.user_stat.update_columns(digest_attempted_at: nil)
    }
    [
      *jobs,
      delivery_op(c, "Jobs::UserEmail user_mentioned") {
        reset.call
        Jobs::UserEmail.new.execute(type: "user_mentioned", user_id: user.id, post_id: post.id, notification_id: mention.id)
      },
      delivery_op(c, "Jobs::CriticalUserEmail forgot_password") {
        reset.call
        Jobs::CriticalUserEmail.new.execute(type: "forgot_password", user_id: user.id, email_token: token)
      },
      delivery_op(c, "Jobs::UserEmail digest") {
        reset.call
        Jobs::UserEmail.new.execute(type: "digest", user_id: user.id)
      },
    ]
  end

  # Chatwoot: Active Job (Sidekiq in production) for everything an agent reply
  # triggers, Action Cable for the dashboard (RoomChannel, pubsub tokens
  # instead of cookies), Active Storage for avatars and message attachments,
  # (agent notification mail does not render on Rails main, below).
  def chatwoot(c)
    boot(c)
    jobs = request_jobs(c, "chatwoot")
    account = Account.find_by!(name: "Census Inc")
    admin = User.find_by!(email: "census-admin@census.test")
    conversation = account.conversations.joins(:inbox).where(inboxes: { channel_type: "Channel::WebWidget" }).order(:id).first!
    message = conversation.messages.where("content LIKE 'Census bg attachment%'").first ||
      conversation.messages.create!(account: account, inbox: conversation.inbox, sender: admin, message_type: :outgoing,
        content: "Census bg attachment")
    attachment = message.attachments.first || message.attachments.create!(account: account, file_type: :image)
    ensure_attached(attachment, :file, fixture_file("photo.jpg"), "image/jpeg")
    ensure_attached(admin, :avatar, fixture_file("avatar.png"), "image/png")
    room = { "channel" => "RoomChannel", "pubsub_token" => admin.pubsub_token, "user_id" => admin.id, "account_id" => account.id }
    [
      *replay_job_ops(c, jobs),
      # No mailer workloads (recorded): Chatwoot's EmailTemplates::DbResolverService
      # calls ActionView::Resolver#_find_all, a private method Rails main no longer has.
      subscribe_op(c, "dashboard (RoomChannel)", {}, [room]),
      perform_op(c, "RoomChannel#update_presence", {}, room, { "action" => "update_presence" }),
      broadcast_op(c, "message.created event") {
        ActionCableBroadcastJob.perform_now([admin.pubsub_token, "account_#{account.id}"], "message.created", message.push_event_data)
      },
      op(c, "AS Message#push_event_data with attachment", :storage) {
        raise "no attachment url" if Message.find(message.id).push_event_data[:attachments].first[:data_url].empty?
      },
      op(c, "AS User#avatar_url", :storage) { raise "no avatar url" if User.find(admin.id).avatar_url.empty? },
      *storage_ops(c, "message attachment", Attachment, attachment.id, :file, variant: { resize_to_fill: [250, nil] }),
      *storage_ops(c, "user avatar", User, admin.id, :avatar, variant: { resize_to_fill: [250, nil] }),
    ]
  end

  # Loomio: Active Job (Solid Queue in production) for what a comment
  # triggers, topic-item notification mail as its subscriber worker sends it,
  # the login-token mail, and Active Storage group logos and covers (served
  # as representation paths in its JSON).
  def loomio(c)
    boot(c)
    jobs = request_jobs(c, "loomio")
    user = User.find_by!(email: "ada@census.test")
    group = user.groups.order(:id).first!
    discussion = group.discussions.order(:id).first!
    # A member Loomio would mail (its seeds also use reserved .example addresses, which it refuses).
    mailer = NotificationMailer.new
    recipient = group.members.where.not(id: user.id).merge(User.active).where(email_verified: true).order(:id)
      .find { !mailer.send(:rejected_address?, _1.email) } or raise "loomio: no mailable member"
    topic_item = TopicItem.where(itemable_type: "Comment").order(:id).first!
    token = LoginToken.where(user: user, used: false).order(:id).first || LoginToken.create!(user: user)
    ensure_attached(group, :logo, fixture_file("avatar.png"), "image/png")
    ensure_attached(group, :cover_photo, fixture_file("photo.jpg"), "image/jpeg")
    ensure_attached(user, :uploaded_avatar, fixture_file("avatar.png"), "image/png")
    [
      *replay_job_ops(c, jobs),
      *mail_ops(c, "NotificationMailer#topic_item") { NotificationMailer.topic_item(recipient.id, topic_item.id) },
      *mail_ops(c, "UserMailer#login") { UserMailer.login(user.id, token.id) },
      op(c, "AS Group#logo_url and #cover_url", :storage) {
        g = Group.find(group.id)
        raise "no logo url" unless g.logo_url && g.cover_url
      },
      *storage_ops(c, "group logo", Group, group.id, :logo, variant: { resize_to_limit: [512, 512] }),
      *storage_ops(c, "user avatar", User, user.id, :uploaded_avatar, variant: { resize_to_limit: [128, 128] }),
    ]
  end

  # Docuseal (e-signature): native Sidekiq jobs from an API submission, the
  # submitter invitation and completion mail, and Active Storage for a user's
  # signature and a template's documents (its seeds attach none, so one image
  # is attached to each).
  def docuseal(c)
    boot(c)
    jobs = request_job_ops(c, "docuseal")
    user = User.find_by!(email: "ada@census.test")
    template = Template.order(:id).first!
    submitter = Submitter.where(completed_at: nil, template_id: template.id).order(:id).first!
    completed = Submitter.where.not(completed_at: nil).order(:id).first!
    ensure_attached(user, :signature, fixture_file("avatar.png"), "image/png")
    unless template.documents.any? { _1.filename.to_s == "photo.jpg" }
      template.documents.attach(ActiveStorage::Blob.create_and_upload!(io: File.open(fixture_file("photo.jpg"), "rb"),
        filename: "photo.jpg", content_type: "image/jpeg", identify: false))
    end
    [
      *jobs,
      *mail_ops(c, "SubmitterMailer#invitation_email") { SubmitterMailer.invitation_email(submitter) },
      *mail_ops(c, "SubmitterMailer#completed_email") { SubmitterMailer.completed_email(completed, user) },
      *storage_ops(c, "user signature", User, user.id, :signature, variant: { resize_to_limit: [400, 200] }),
      op(c, "AS template documents url_for", :storage) {
        Template.find(template.id).documents.each { url_helpers.polymorphic_url(_1) }
      },
    ]
  end

  # The Blog: Turbo Streams model broadcasts (broadcasts_to) and their jobs.
  def blog(c)
    boot(c)
    jobs = request_jobs(c, "blog")
    article = Article.order(:id).first!
    [
      *replay_job_ops(c, jobs),
      broadcast_op(c, "Article#broadcast_replace_to articles") { article.broadcast_replace_to("articles") },
      subscribe_op(c, "articles index (articles stream)", {}, [turbo_stream("articles")]),
    ]
  end

  # CodeTriage: the triage email job (its Markdown mail does not render on
  # Rails main: maildown 3.3.1 calls the removed
  # ActionView::Template.registered_template_handler, as in census 4).
  def codetriage(c)
    boot(c)
    sub = User.find_by!(github: "schneems").repo_subscriptions.first!
    job_ops(c, "SendSingleTriageEmailJob") { SendSingleTriageEmailJob.perform_later(sub.id) }
  end

  # Thinkroom: Action Cable document channels (DocumentMetaChannel; SyncChannel
  # relays Yjs updates through y-rb) and the jobs a comment enqueues.
  def thinkroom(c)
    boot(c)
    jobs = request_jobs(c, "thinkroom")
    doc = Document.find_by!(slug: "demo")
    meta = { "channel" => "DocumentMetaChannel", "slug" => doc.slug }
    [
      *replay_job_ops(c, jobs),
      subscribe_op(c, "document page (DocumentMetaChannel)", {}, [meta]),
      broadcast_op(c, "DocumentMetaChannel.broadcast_event") { DocumentMetaChannel.broadcast_event(doc, :comments, count: 1) },
    ]
  end
end
