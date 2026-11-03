# Loomio census data: one member and Loomio's own code-backed demo group
# (DemoGroupTemplateService: threads, comments, polls and votes), plus a second
# member so the group has more than one participant.
srand(42)
user = User.create!(name: "Ada Census", email: "ada@census.test", password: "census-password-123", email_verified: true)
DemoGroupTemplateService.create!(template_key: "mobile", user: user)
group = user.groups.first!
other = User.create!(name: "Bea Census", email: "bea@census.test", password: "census-password-123", email_verified: true)
group.add_member!(other)
puts({ groups: Group.count, discussions: Discussion.count, polls: Poll.count, comments: Comment.count }.inspect)
