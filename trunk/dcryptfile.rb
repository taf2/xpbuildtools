#!/usr/bin/env ruby

puts "Decrypts a backup file #{ARGV[0]}"
if !ARGV[0] 
	puts "Usage: > dcryptfile.rb backup.sbx"
	puts "will generate a file backup.sbx.dcrypt that you can read"
	puts "See also decrypter.html for single-string en/decrypter"
	puts "Warning: this encryption not to be used for security purposes; it's pretty easy to break."
  puts "This file does the informal decryption of individual xml fields in an 'unencrypted' backup file."
  puts "IF the user chooses a password to encrypt bakup files - this won't help you."
	puts "you need the full Simo client program to decrypt that.  "
	exit 1
end

infile = File.new(ARGV[0], "rb");
outfile = File.new(ARGV[0] + ".dcrypt", "wb");

while line = infile.gets

	# most of the encrypted stuff is these cdatas for char string data
	if line =~ /CDATA\[(.*)\]\]>/
		#puts "the line has cdata #$1"
		tbefore = $`
		tafter = $'

		res = String.new
		mode = 0  # next time dont use an iterator
		cval = 0
		$1.each_byte {|c|
			if mode == 0
				if c == 37 # % char
					mode = 1
					#puts ">mode 1"
				else
					res << 158 - c;
				end
			elsif mode == 1
				cval = (c>0x39 ? c+9 : c) & 15
				cval <<= 4
				mode = 2
				#puts "mode 1: char #{c} yields #{cval}"
			elsif mode == 2
				cval |= (c>0x39 ? c+9 : c) & 15
				res << ((158 - cval) & 255);
				mode = 0
				#puts "mode 2: char #{c} yields #{cval}"
			end

		}
		line = tbefore + 'CDATA[' + res + ']]>' + tafter
		#puts "Result is #{res}"
	end

	# the id's get encrypted by incrementing the char code only
	if line =~ / id="(.*)" index/
		#puts "the line has an id #$1"
		tbefore = $`
		tafter = $'

		res = String.new
		mode = 0
		cval = 0
		$1.each_byte {|c|
			res << c - 1;
		}
		line = tbefore + ' id="' + res + '" index' + tafter
		#puts "Result is #{res}"
	end

	outfile.puts line
end

infile.close
outfile.close

