# frozen_string_literal: true

# MB1 differential probe: Relation#merge and merge! with blank and near-blank
# relations, in a Lobsters census copy; run it on both trees and diff OUT:
#   [PMAP_RAILS=SPEC] bench/upstream/p_map/hx CORPUS lobsters bundle exec ruby THIS OUT
require_relative "../census/harness"
RailsCensus.boot("lobsters")
require "digest"
story = Story.order(:id).first
user = User.order(:id).first
blank = ->(m) { m.send(:relation) }
others = {
  "blank Story" => -> { blank.(Story) },
  "blank Comment (other model)" => -> { blank.(Comment) },
  "Story.unscoped" => -> { Story.unscoped },
  "Story.all" => -> { Story.all },
  "Story.none" => -> { Story.none },
  "Story.none.only(:order)" => -> { Story.none.only(:order) },
  "Story.none.except(:where)" => -> { Story.none.except(:where) },
  "Story.where(id: 1).except(:where)" => -> { Story.where(id: 1).except(:where) },
  "Story.extending(Module.new)" => -> { Story.extending(Module.new { def probe = 1 }) },
  "Story.where({})" => -> { Story.where({}) },
  "Story.unscope(:where)" => -> { Story.unscope(:where) },
  "Story.order(:id).unscope(:order)" => -> { Story.order(:id).unscope(:order) },
  "Story.strict_loading(false)" => -> { Story.strict_loading(false) },
  "Story.readonly(false)" => -> { Story.readonly(false) },
  "user.stories (proxy)" => -> { user.stories },
  "Comment.where(story_id: 1)" => -> { Comment.where(story_id: 1) },
}
receivers = {
  "Story.all" => -> { Story.all },
  "Story.where(id: 1)" => -> { Story.where(id: 1) },
  "Story.none" => -> { Story.none },
  "user.stories (proxy)" => -> { user.stories },
  "user.stories.where(is_deleted: false)" => -> { user.stories.where(is_deleted: false) },
  "story.comments" => -> { story.comments },
  "Story.where(id: 1) after .arel" => -> { r = Story.where(id: 1); r.arel; r },
  "Story.all after .arel" => -> { r = Story.all; r.arel; r },
  "Story.where(id: 1) loaded" => -> { r = Story.where(id: 1); r.load; r },
}
def describe(r)
  [r.class.name, r.null_relation?, (r.to_sql rescue "ERR #{$!.class}"), r.values.keys.sort.inspect, (r.respond_to?(:probe) ? r.probe : nil), (r.to_a.size rescue "ERR #{$!.class}")].inspect
end
out = []
receivers.each do |rn, rb|
  others.each do |on, ob|
    %i[merge merge!].each do |m|
      res = begin
        rel = rb.call
        o = ob.call
        r = rel.public_send(m, o)
        "#{describe(r)} same_object=#{r.equal?(rel)} receiver=#{describe(rel)}"
      rescue => e
        "raise #{e.class}: #{e.message[0, 80]}"
      end
      out << "#{rn} | #{m} | #{on} => #{res}"
    end
  end
end
File.write(ARGV[0], out.join("\n") + "\n")
puts "#{out.size} cases, digest #{Digest::SHA256.hexdigest(out.join("\n"))[0, 16]}"
