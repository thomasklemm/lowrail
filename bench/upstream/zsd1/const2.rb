BUF = +"abc"
def f = BUF.dup
10.times { f }
out = []
out << [f, f.encoding, f.bytesize]
BUF << "xyz"
out << [f, f.encoding, f.bytesize]
BUF.force_encoding(Encoding::BINARY)
out << [f, f.encoding]
BUF.replace("Q")
out << [f, f.encoding, f.bytesize]
BUF.replace("é")
out << [f, f.encoding, f.valid_encoding?, f.ascii_only?]
BUF.clear
out << [f, f.bytesize]
BUF.replace("z" * 40)
out << [f.bytesize]
out.each { p it }
