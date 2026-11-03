# frozen_string_literal: true

# Flow (Aixle) census data (docs/upstream/inertia-chatwoot-census.md). Its
# db/seeds.rb returns outside development and test, so only that check is
# answered as local while it runs; Rails.env itself (and with it every database
# configuration) stays production. Then the demo board gets the tasks a team's
# board carries: 48 across its columns, with types, priorities, tags, assignees
# and comments, written through the models as the app's own API does.
srand(42)
Rails.env.define_singleton_method(:local?) { true }
begin
  load "db/seeds.rb"
ensure
  Rails.env.singleton_class.remove_method(:local?)
end

project = Project.find_by!(slug: "demo-alpha")
board = project.board
columns = board.board_columns.order(:position).to_a
users = project.member_users.to_a
types = %w[story bug not_specified epic]
priorities = %w[low medium high critical]
tags = %w[backend frontend api billing auth infra docs ux]
48.times do |i|
  task = board.board_tasks.create!(board_column: columns[i % columns.size], title: "Census task #{i + 1}: #{%w[Fix Add Refactor Document Investigate][i % 5]} #{tags[i % tags.size]} flow",
    description: "Census task #{i + 1}. " * 8, assignee: users[i % users.size], task_type: types[i % types.size],
    priority: priorities[i % priorities.size], tags: tags.sample(2))
  board.board_activities.create!(board_task: task, actor: users[i % users.size], actor_type: :human, event_type: :task_created)
  (i % 3).times do |n|
    task.task_comments.create!(author: users[n % users.size], body: "Census comment #{n + 1} on task #{i + 1}")
    board.board_activities.create!(board_task: task, actor: users[n % users.size], actor_type: :human, event_type: :comment_added)
  end
end
