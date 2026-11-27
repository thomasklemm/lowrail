require "bundler/setup"
require "cases/helper"
require "models/topic"
require "models/reply"
require "active_support/message_pack"
require "active_record/message_pack"
require "json"

factory = MessagePack::Factory.new
ActiveRecord::MessagePack::Extensions.install(factory)
ActiveSupport::MessagePack::Extensions.install(factory)
Dir[File.join(ENV.fetch("TMPDIR"), "rails_6_1_*.dump")].sort.each do |file|
  %i[attributes_before_type_cast attributes_for_database title].each do |first|
    begin
      topic = Marshal.load(File.binread(file))
      topic.public_send(first)
      result = [File.basename(file), first, topic.title, topic.attributes_before_type_cast,
        topic.attributes_for_database, topic.changes, topic.accessed_fields,
        Marshal.load(Marshal.dump(topic)).attributes_for_database,
        factory.load(factory.dump(topic)).attributes_for_database]
      puts "LEGACY #{JSON.generate(result)}"
    rescue => e
      puts "LEGACY #{JSON.generate([File.basename(file), first, e.class.name, e.message])}"
    end
  end
end
