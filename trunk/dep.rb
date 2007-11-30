#!/usr/bin/env ruby
# scan C/C++ files for headers and create dependency rules

require 'fileutils'
require 'pathname'
require 'pp'

module Build
	
	def self.scan_file( src )
		content = File.new( src ).read(1024) # read the first 1024 lines of the file
		if content != nil 
			content.each_line{|line|
				inc = line.match(/#include[ ]*\"[a-zA-Z][a-zA-Z]*/)
				if( inc && inc.length > 0 )
					inc = inc[0].match(/\"[a-zA-Z][a-zA-Z]*/)
					if( inc && inc.length > 0 )
						file = Pathname.new( "#{inc[0].gsub(/"/, "")}.h" )
						if( file.exist? )
							printf "#{file.to_s} "
						end
					end
				end
			}
		end
	end

	# usage: sourcefile target.d
	def self.run(args)
		begin
			if( args.length < 3 )
				STDERR.printf( "usage: #{$0} target_name sourcefile target.d\n" )
				exit
			end
			name = args[0]
			src = args[1]
			obj = "$(OBJDIR)/objects/#{name}/#{src.gsub( /\.c*$/, ".$(OBJ_SUFFIX)" )}"
			dep = "$(OBJDIR)/objects/#{name}/#{args[2]}"
			# output first part of dependency rule
			if File.exist?( src )
				printf "#{obj}:#{src} "
				Build.scan_file( src )
				printf( "\n" )
			else
				STDERR.printf( "Error File Not Found: %s\n", src )
				exit 1
			end
		rescue Exception => e
			STDERR.printf( "Error: %s\n", e )
			exit 1
		end
		pp "#{dep}:#{src}"
	end

end

Build.run(ARGV)
