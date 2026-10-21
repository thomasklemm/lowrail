# frozen_string_literal: true

# Non-deployable bench artifact. Every arm cold-delivers the SAME seams.
# No TracePoint, Binding, template compilation, resolver or runtime app edits.
require "digest"
require "json"
require "fileutils"
require_relative "../../gem/lib/lowrail/compiler"
require_relative "../../gem/lib/lowrail/sealed"

module BlockLinkDelivery
  STOCK = {
    "base.rb" => "f4f6e92b471923d4ad89205fa7ed8f60b005bdb5de33bf8c9e93bf7303aa0e4c",
    "buffers.rb" => "3273ae55826b56e2e86e0d71fbb2dea8faa2a2eb468951714760a55e501abe70",
    "helpers/url_helper.rb" => "ebdccd38cf87f6f83d758ba424df61d72c8033629f0e70a8ddb21b7b8ed086ee",
    "helpers/tag_helper.rb" => "7bca8efe1bd2421c5e65671aabdf35c97831ab0cb2cbdcdb5dd317d22aa16c31",
    "helpers/capture_helper.rb" => "9cc89ba1f287b09e79569f61500e2652d9d169a962e7ea6217a3f1920cbda76b"
  }.freeze
  AUDIT = {
    "actionview:lib/action_view/template.rb" => "defe875aa54871a597eb37c846636cce70ba782d61bb39cd8e5332acbda0a3c6",
    "actionview:lib/action_view/template/handlers/erb.rb" => "1eb6d4ba4690103fc161eb9d5ef7d79d4b977cc04bbbfa3482e17270c2ef988d",
    "actionview:lib/action_view/template/handlers/erb/erubi.rb" => "a8f9d22dfce5478e89815c96a9b2035ca7c2dd0fbabe4774b2e30f0e9f99bf49",
    "activesupport:lib/active_support/core_ext/object/blank.rb" => "203eefc5b094f4a0f5bf68b4c34198891127f52ed7825e146c2fa089a46f8ec7",
    "activesupport:lib/active_support/core_ext/erb/util.rb" => "1e348e9c8840caa9942691a290e0424c1755256b03a90eb96a094bbf86ff368f",
    "activesupport:lib/active_support/core_ext/string/output_safety.rb" => "8d8c461dbcd14db6b894671a1ec53b03c39637a67c27222e7d22bbe3c2f411d6"
  }.freeze

  module_function

  def replace(source, before, after)
    raise "ambiguous stock seam: #{before}" unless source.scan(before).size == 1
    raise "line drift" unless before.count("\n") == after.count("\n")
    source.sub(before, after)
  end

  def sources
    root = (Gem::Specification.find_by_name("actionview", "8.1.4").full_gem_path + "/lib/action_view/").encode(Encoding::UTF_8)
    STOCK.to_h do |relative, pin|
      path = root + relative
      source = File.read(path)
      raise "stock source pin mismatch #{relative}" unless Digest::SHA256.hexdigest(source) == pin
      edited = case relative
      when "base.rb"
        code = replace(source, "@output_buffer = buffer\n", "@output_buffer = buffer; __bl_context = ::BlockLinkSpecimen.template_enter(self, method, template, locals, buffer, has_strict_locals)\n")
        replace(code, "@output_buffer, @virtual_path, @current_template = _old_output_buffer, _old_virtual_path, _old_template",
          "::BlockLinkSpecimen.template_leave(__bl_context); @output_buffer, @virtual_path, @current_template = _old_output_buffer, _old_virtual_path, _old_template")
      when "buffers.rb"
        code = replace(source, "old_buffer, @raw_buffer = @raw_buffer, new_buffer",
          "old_buffer, @raw_buffer = @raw_buffer, new_buffer; __bl_buffer = ::BlockLinkSpecimen.buffer_enter(self, old_buffer, new_buffer)")
        replace(code, "@raw_buffer = old_buffer\n", "@raw_buffer = old_buffer; ::BlockLinkSpecimen.buffer_leave(__bl_buffer, self, old_buffer, new_buffer, @raw_buffer)\n")
      when "helpers/url_helper.rb"
        code = replace(source, "def link_to(name = nil, options = nil, html_options = nil, &block)",
          "def link_to(name = nil, options = nil, html_options = nil, &block); __bl_call = ::BlockLinkSpecimen.link_enter(self, block, name, options, html_options); begin")
        replace(code, 'content_tag("a", name || url, html_options, &block)',
          '__bl_result = content_tag("a", name || url, html_options, &block); ::BlockLinkSpecimen.link_completed(__bl_call, __bl_result); __bl_result; ensure; ::BlockLinkSpecimen.link_leave(__bl_call); end')
      when "helpers/tag_helper.rb"
        code = replace(source, "@tag_builder ||= TagBuilder.new(self)",
          "@tag_builder ||= (begin; __bl_constructor = ::BlockLinkSpecimen.constructor?(TagBuilder); __bl_builder = TagBuilder.new(self); ::BlockLinkSpecimen.builder_created(self, __bl_builder, __bl_constructor); __bl_builder; end)")
        replace(code, "tag_builder.content_tag_string(name, capture(&block), options, escape)",
          "__bl_builder = tag_builder; __bl_capture = ::BlockLinkSpecimen.capture_begin(self, __bl_builder, block, name, options, escape); __bl_content = capture(&block); ::BlockLinkSpecimen.capture_end(__bl_capture); if ::BlockLinkSpecimen.fast?(__bl_capture, __bl_builder, __bl_content, options, escape); ::BlockLinkSpecimen.render(__bl_capture, __bl_content, options); else; __bl_builder.content_tag_string(name, __bl_content, options, escape); end")
      when "helpers/capture_helper.rb"
        replace(source, "buffer = @output_buffer.capture { value = yield(*, **) }",
          "buffer = ::BlockLinkSpecimen.capture_receiver(self, @output_buffer).capture { value = yield(*, **) }")
      end
      [path, {"original" => source, "code" => edited, "sha256" => pin}]
    end
  end

  def build(app, destination)
    raise "new bench artifact required" if File.exist?(destination)
    FileUtils.mkdir_p(destination, mode: 0o700)
    files = sources.map.with_index do |(path, data), index|
      lowered = File.join(destination, "#{index}.rb")
      File.write(lowered, data.fetch("code"))
      {"path" => path, "lowered" => lowered, "source_sha256" => data.fetch("sha256")}
    end
    input = {"app_root" => app, "out" => destination, "rails_env" => "production",
      "certification_jit" => "interpreter", "files" => files,
      "units" => files.map.with_index { |file, id| {"id" => id, "kind" => "file", "pass" => "bench/block_link", "file" => file.fetch("path"), "facts" => []} }}
    # Disposable BUILD process: observe the app's real per-file compiler
    # recipes during original production boot. No template renders/handlers.
    Dir.chdir(app) do
      Lowrail::Compilation.boot(input) do
        require File.join(app, "config/application")
        Rails.application.config.yjit = false
      end
    end
    manifest = Lowrail::Compiler.compile(input)
    expected = {}
    sequences = files.to_h do |file|
      path = file.fetch("path")
      [path, Lowrail::Compilation.lowered(File.read(file.fetch("lowered")), path, Lowrail::Compilation.files.fetch(path))]
    end
    audit_sources = AUDIT.to_h do |key, pin|
      gem_name, relative = key.split(":", 2)
      path = File.join(Gem.loaded_specs.fetch(gem_name).full_gem_path, relative).encode(Encoding::UTF_8)
      raise "audit source pin mismatch #{relative}" unless Digest::SHA256.file(path).hexdigest == pin
      sequences[path] = RubyVM::InstructionSequence.compile(File.read(path), path, path, 1)
      [path, pin]
    end
    sequences.each do |path, sequence|
      visit = lambda do |child|
        expected[JSON.generate([path, child.label, child.first_lineno])] = Lowrail::Sealed.signature(
          Object.instance_method(:instance_variable_get), sequence: child.to_a).fetch("iseq")
        child.each_child { visit.call(_1) }
      end
      visit.call(sequence)
    end
    File.write(File.join(destination, "expected-methods.json"), JSON.generate(expected))
    File.write(File.join(destination, "audit-sources.json"), JSON.generate(audit_sources))
    manifest
  end
end
