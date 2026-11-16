# frozen_string_literal: true
rails = ARGV.fetch(0)
%w[activesupport activemodel].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"; require "active_support/core_ext"; require "active_model"
require "action_view" rescue nil
$LOAD_PATH.unshift(File.join(rails, "actionview", "lib")); require "action_view"
require_relative "form_stack_patches"
class P; include ActiveModel::Model; attr_accessor :name, :age; end
class SubStr < String; def to_sym = (puts "to_sym called"; super); end
def show(&b) = (b.call.inspect rescue "#{$!.class}: #{$!.message}")
e = P.new.errors
f = P.new.errors; f.add(:name, :blank); f.add(:age, :invalid, count: 2)
[e, f].each do |errs|
  [:name, "name", :age, SubStr.new("name"), 1, nil, Object.new.tap { |o| def o.inspect = "obj" }].each do |a|
    puts show { errs[a] }, show { errs.where(a, :blank) }, show { errs.where(a, nil, count: 2) },
         show { errs.messages_for(a) }, show { errs.include?(a) }, show { errs.where(a, ->(base, opts) { puts "proc"; :blank }) }
  end
end
