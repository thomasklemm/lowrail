# ruby -Ilib -Itest/lib eval_asserts.rb ASSERTS_FILE: evaluates each assertion alone and prints the failing lines.
# frozen_string_literal: false
require "uri"
require "test/unit/assertions"
include Test::Unit::Assertions
load ARGV[0]
failed = ASSERTS.map do |meth, line, code|
  begin
    eval(code, binding, "t", line)
    nil
  rescue Exception => e
    "#{meth}:#{line}"
  end
end
puts failed.compact.join(" ")
