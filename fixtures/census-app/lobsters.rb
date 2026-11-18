# Lobsters' workloads as its developer would write them: a signed-in member
# reading and writing.
user = User.active.where(is_moderator: false).order(:id).first!

setup do
  Comment.where("comment LIKE 'Census comment%'").find_each { |cm| Vote.where(comment_id: cm.id).delete_all; cm.delete }
  user.update!(password: "census-password", password_confirmation: "census-password")
end

shown, target, voted = Story.where(is_deleted: false, merged_story_id: nil).where.not(user_id: user.id).order(:id).first(3)
tag = shown.tags.first!

sign_in "/login", params: { email: user.email, password: "census-password" }, expect: 302
csrf_from "/"

get "/", name: "GET home"
get "/active", name: "GET active"
get "/s/#{shown.short_id}/#{shown.title_as_slug}", name: "GET story"
get "/t/#{tag.tag}", name: "GET tag"
get "/hottest.json", as: :json, name: "GET hottest.json"
get "/s/#{shown.short_id}.json", as: :json, name: "GET story.json"

post "/stories/#{voted.short_id}/upvote", xhr: true, name: "POST story vote toggle", expect: 200,
  alternate: [{ path: "/stories/#{voted.short_id}/upvote" }, { path: "/stories/#{voted.short_id}/unvote" }]
post "/comments", xhr: true, name: "POST comment preview", expect: 200,
  params: { story_id: target.short_id, comment: "Census preview", preview: "1" }
# A block gets the run's number: every comment differs.
post "/comments", xhr: true, name: "POST comment (XHR)", expect: 200, jobs: true do |n|
  { params: { story_id: target.short_id, comment: "Census comment #{n}" } }
end
skip_jobs "CachePageJob"

# The comment the POST above created, looked up when the mail first runs.
let(:reply) { Comment.where(story_id: target.id).order(:id).last! }
let(:recipient) { User.find(target.user_id) }
mail { EmailReplyMailer.reply(reply, recipient) }
