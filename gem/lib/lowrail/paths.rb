# frozen_string_literal: true

module Lowrail
  # Only typed metadata is relocatable. Never substitute paths in Ruby source,
  # configuration, schema literals or reflection options. JSON pointers keep
  # the readers independent of the certificate schemas that the writer knows.
  module Paths
    module_function

    def relative(data, root:, dir:)
      require "pathname" # build time only; runtime setup loads no default gems
      data = JSON.parse(JSON.generate(data))
      root = File.expand_path(root)
      paths = { "values" => [], "keys" => [] }
      visit = ->(value, pointer) {
        case value
        when Hash
          value.each do |key, child|
            at = "#{pointer}/#{key.gsub('~', '~0').gsub('/', '~1')}"
            if %w[files templates sources].include?(key) && child.is_a?(Hash)
              changed = false
              child.replace(child.to_h { |path, entry|
                relative = relative_path(path, root)
                changed ||= relative != path
                [relative, entry]
              })
              paths["keys"] << at if changed
            end
            if %w[source_location const_source_location identifier file caller].include?(key) ||
                (%w[scope original].include?(key) && child.is_a?(Array)) ||
                (key == "filter" && value["filter_type"] == "proc")
              location = child.is_a?(Array) ? "#{at}/0" : at
              make_relative(data, location, root, paths) if child.is_a?(String) || child.is_a?(Array)
            end
            if key == "types" && child.is_a?(Hash)
              child.each do |type, methods|
                methods.each do |name, chain|
                  chain.each_index do |i|
                    next unless chain[i].is_a?(Array)
                    parts = [type, name, i, 0].map { _1.to_s.gsub('~', '~0').gsub('/', '~1') }
                    make_relative(data, "#{at}/#{parts.join('/')}", root, paths)
                  end
                end
              end
            end
            next if %w[options config default defaults].include?(key)
            visit.call(child, at)
          end
        when Array
          value.each_with_index { |child, i| visit.call(child, "#{pointer}/#{i}") }
        end
      }
      visit.call(data, "")
      Array(data["gems"]).each_index { make_relative(data, "/gems/#{_1}/path", root, paths) }
      Array(data["generated_scripts"]).each_index { make_relative(data, "/generated_scripts/#{_1}/path", root, paths) }
      Array(data["load_path_features"]).each_index { make_relative(data, "/load_path_features/#{_1}", root, paths) }
      data["app_root"] = Pathname.new(root).relative_path_from(Pathname.new(File.expand_path(dir))).to_s
      data["app_paths"] = paths
      data
    end

    def relative_path(path, root)
      return path unless path.is_a?(String)
      prefix = path.start_with?("(eval at ") ? "(eval at " : ""
      value = path.delete_prefix(prefix)
      return "#{prefix}." if value == root
      return path unless File.expand_path(value) == value
      value.start_with?(root + "/") ? prefix + value.delete_prefix(root + "/") : path
    end

    def make_relative(data, pointer, root, paths)
      parent, key = at(data, pointer)
      path = parent[key]
      relative = relative_path(path, root)
      return if relative == path
      parent[key] = relative
      paths["values"] << pointer
    end

    def at(data, pointer)
      parts = pointer.delete_prefix("/").split("/").map { _1.gsub('~1', '/').gsub('~0', '~') }
      key = parts.pop
      parent = parts.reduce(data) { |node, part| node.is_a?(Array) ? node.fetch(Integer(part)) : node.fetch(part) }
      [parent, parent.is_a?(Array) ? Integer(key) : key]
    end

    # Mutate the parsed document, so callers retaining it (bench preflight)
    # see the same resolved paths as Manifest. Only registered fields change.
    def resolve!(data, root:)
      return data unless (paths = data["app_paths"])
      paths.fetch("values").each do |pointer|
        parent, key = at(data, pointer)
        path = parent.fetch(key)
        prefix = path.start_with?("(eval at ") ? "(eval at " : ""
        parent[key] = prefix + File.expand_path(path.delete_prefix(prefix), root)
      end
      # Children still use their relative parent keys in the pointer table.
      paths.fetch("keys").reverse_each do |pointer|
        parent, key = at(data, pointer)
        entries = parent.fetch(key)
        entries.replace(entries.to_h { |path, entry| [File.expand_path(path, root), entry] })
      end
      data["app_root"] = root
      data.delete("app_paths")
      data
    end

    def contains_root?(value, root)
      case value
      when String then value.include?(root)
      when Array then value.any? { contains_root?(_1, root) }
      when Hash then value.any? { |key, child| contains_root?(key, root) || contains_root?(child, root) }
      else false
      end
    end
  end
end
