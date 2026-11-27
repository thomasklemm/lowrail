begin
  eval("raise 'boom'", nil, "a\0b.rb")
rescue => e
  p e.backtrace[0].sub("\0", "<NUL>")
end
