# frozen_string_literal: true

# Objects and ns per AbstractController::Rendering#view_assigns on a controller
# with five app ivars after processing-like state (17 ivars).
#   BUNDLE_GEMFILE=RAILS/Gemfile bundle exec ruby [--yjit] micro_view_assigns.rb
require "action_controller"

class BenchController < ActionController::Base
  def setup_ivars
    %i[@_request @_response @_routes @_action_name @_response_body @_formats @_prefixes @_lookup_context
       @_view_renderer @_rendered_format @_marked_for_same_origin_verification @_params].each { instance_variable_set(_1, nil) }
    @post = 1; @comments = 2; @user = 3; @page = 4; @title = 5
  end
end

c = BenchController.new
c.setup_ivars
puts "#{RUBY_DESCRIPTION}\nivars: #{c.instance_variables.size}, protected: #{c.send(:_protected_ivars).size}, assigns: #{c.view_assigns.keys.inspect}"
5.times { c.view_assigns }
GC.disable
before = GC.stat(:total_allocated_objects)
1000.times { c.view_assigns }
objects = (GC.stat(:total_allocated_objects) - before) / 1000.0
GC.enable
n = 300_000
ns = 3.times.map do
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  n.times { c.view_assigns }
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) / n * 1e9
end.min
puts format("view_assigns  %.2f objects  %.1f ns", objects, ns)
