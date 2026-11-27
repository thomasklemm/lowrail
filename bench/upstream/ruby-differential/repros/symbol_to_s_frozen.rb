# Discourse PostMover#create_moderator_post_in_original_topic: `PostMover.move_types[@move_type].to_s` (a Symbol)
# then `sub!("topic", "message")`. Ruby 4.0.9 returns a chilled String (a warning under -W:deprecated); master
# returns a frozen one.
s = :new_topic.to_s
s.sub!("topic", "message")
p s
