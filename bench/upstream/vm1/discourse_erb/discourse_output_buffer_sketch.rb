# Sketch for option (b), not posted: Discourse repairs invalid UTF-8 where Rails main escapes template
# appends, in addition to its ERB::Util patch (lib/freedom_patches/erb_util.rb), which still covers
# html_escape, h and the tag helpers. Works on Rails 8.1 too (the second repair is a no-op there).
module FreedomPatches
  module OutputBuffer
    def <<(value)
      unless value.nil?
        value = value.to_s
        unless value.html_safe? || value.valid_encoding?
          value = ActiveSupport::Multibyte::Unicode.tidy_bytes(value)
        end
      end
      super(value)
    end
    alias_method :concat, :<<
    alias_method :append=, :<<
  end
end

ActionView::OutputBuffer.prepend(FreedomPatches::OutputBuffer)
