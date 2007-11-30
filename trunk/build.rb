#!/usr/bin/env ruby
# --
# Features:
# * Building dynamic libraries
# * Building static libraries
# * Building executables
# ++

require 'find'
require 'fileutils'
require 'pathname'
require 'rexml/document'
require 'pp'

include REXML

module Build

	class Makefile
		attr_reader :path
		def initialize(root_path, mk_conf, opts)
			@configs = []
			@bins = []
			@sharedlibs = []
			@staticlibs = []

			@path = Pathname.new( File.dirname(mk_conf) ).realpath

			doc = Document.new(File.new(mk_conf))
			
			doc.elements.each( "make" ){|element| 
				@includes = Build.get_block_items( element, "include" )
			}

			@custom = []
			doc.elements.each( "make/custom" ){|element| 
				@custom << CustomTarget.new( element )
			}

			@copy = []
			doc.elements.each( "make/copy" ){|element| 
				@copy << CopyTarget.new( root_path, @path, element, opts )
			}
			
			#doc.elements.each( "make/config" ){|element| @configs << Config.new(@path, element, opts) }
			# collect all library targets
			doc.elements.each( "make/lib" ){|element| 

				type = Build.get_attr(element,"type") # target type static|shared if library
				if( type == "shared" )
					@sharedlibs << SharedLibraryTarget.new(root_path, @path, element, opts) 
				elsif( type == "static" )
					@sharedlibs << StaticLibraryTarget.new(root_path, @path, element, opts) 
				end
			}
			# collect all executable targets
			doc.elements.each( "make/exe" ){|element| 
				@bins << BinTarget.new(root_path, @path, element, opts)
			}
		end

		def write
			begin
				output = MakeBundle.new( @path )
				output.mkfile << "include .make/inc\n\n"
				output.mkfile << "all:$(TARGETS)\n"
				@includes.each{|inc|
					if( inc != "." )
						output.mkfile << "\t$(MAKE) -C #{inc}\n"
					end
				}
				# write all configurations first
				#@configs.each{|config| config.write( output ) }
				@staticlibs.each{|lib| lib.write( output ) }
				# write all library targets
				@sharedlibs.each{|lib| lib.write( output ) }
				# write all binary targets
				@bins.each{|bin| bin.write( output ) }
				# write sql targets
				# write copy rules
				# write custom rules
				output.mkfile << "include .make/stub\n\n"

				output.mkfile << "clean:\n\trm -f $(TARGETS) $(TARGETS_OBJS)\n\techo 'run make clean-all to clean all targets'\n"
				output.mkfile << "clean-all:\n\trm -f $(TARGETS) $(TARGETS_OBJS) $(TARGETS_DEPS) $(TARGETS_EXTRA)\n"
				@includes.each{|inc|
					if( inc != "." )
						output.mkfile << "\t$(MAKE) -C #{inc} clean\n"
					end
				}
				@copy.each{|cp|
					cp.write( output )
				}
				@custom.each{|c|
					c.write( output )
				}
			rescue StandardError => e
				STDERR.printf( e.message )
				e.backtrace.each{|bt|
					STDERR.printf( "#{bt}\n" )
				}
				STDERR.printf( "\n" )
			ensure
				output.close
			end
		end

	end

	class MakeBundle
		attr_reader :mkfile, :inc, :rules, :target_dep_rules 
		attr_writer :target_dep_rules

		def initialize(path)
			@make_dir = Pathname.new(path) + Pathname.new(".make")
			if( !File.exists?( @make_dir.to_s ) )
				FileUtils.mkdir( @make_dir.to_s )
			end

			@mkfile		= File.new((path + Pathname.new("Makefile")).to_s, "w")
			@inc			= File.new((path + Pathname.new(".make/inc")).to_s, "w")
			@rules		= File.new((path + Pathname.new(".make/stub")).to_s, "w")
			@path			= path
			@target_dep_rules = [] # use this array to track dependencies so that we only include rules once for each dependency
		end

		def close
			@mkfile.close
			@inc.close
			@rules.close
		end

	end

	def self.get_attr(el,name)
		attrs = el.attributes
		attrs.get_attribute(name) ? attrs.get_attribute(name).value : ""
	end

	# a block configuring properties in a makefile
	class Config
		def initialize(path,el,opts=nil)
			@path = path
		end
		def write( output )
		end
	end

	# generic class for describing make targets
	class Target
		attr_reader :path, :name
		def initialize(root_path, path, el, opts)
			@opts			= opts
			@os				= @opts.flags['config']['OS_ARCH']
			@root_path= root_path
			@path			= path
			@name			= Build.get_attr(el,"name")
			@install	= Build.get_attr(el,"install")
			@loadpath	= Build.get_attr(el,"loadpath")
			@noinstall= Build.get_attr(el,"noinstall")
			@src			= Build.get_block_items(el,"src")
			@cppflags	= Build.get_block_items(el,"cppflags")
			@cflags		= Build.get_block_items(el,"cflags")
			@cxxflags = Build.get_block_items(el,"cxxflags")
			@ldflags	= Build.get_block_items(el,"ldflags")
			@libs			= Build.get_block_items(el,"libs")
			@deps			= Build.get_block_items(el,"deps")
			@resources= Build.get_block_items(el,"res") # win32 msvc resource files
			@idlfiles = Build.get_block_items(el,"idl")
			@explicitcc  = Build.get_attr(el,"explicitcc")
			@explicitout  = Build.get_attr(el,"explicitout")
			@explicitld  = Build.get_attr(el,"explicitld")
			@explicitldout  = Build.get_attr(el,"explicitldout")
			@def = ""
			@extras = ""
			@voidtarget = "false"

			#puts "Target #{@name} has #{@deps.length} Dependencies"

			if( @noinstall == "true" )
				@install = "."
			end

			if( !@install || @install.empty? )
				@install = "$(OBJDIR)/bin/"
			end

			if( $targets.has_key?( @name ) )
				target = $targets[@name]
				STDERR.printf( "Fatal Error: target at #{path} conflicts with target at #{target.name}\n" )
				exit
			else
				$targets[@name] = self
			end

			el.elements.each('arch'){|element| 
				if( Build.get_attr(element,'type') =~ /#{opts.flags['config']['OS_ARCH']}/ )
					@src			+= Build.get_block_items(element,"src")
					@cppflags	+= Build.get_block_items(element,"cppflags")
					@cflags		+= Build.get_block_items(element,"cflags")
					@cxxflags += Build.get_block_items(element,"cxxflags")
					@ldflags	+= Build.get_block_items(element,"ldflags")
					@libs			+= Build.get_block_items(element,"libs")
					@def			 = Build.get_block_items(element,"def").join(' ') # win32 msvc export file
					@resources+= Build.get_block_items(element,"res") # win32 msvc resource files
					@voidtarget = Build.get_attr(element,"voidtarget")
				end
			}

			@topsrc=Pathname.new(".")
			@path.relative_path_from( @root_path ).each_filename{|part|
				if( part == '.' )
					break
				end
				@topsrc += ".."
			}
			# create the objdir/objects/target_name for this target
			@objdir=Pathname.new(opts.mode + "-" + opts.brand)
			@objects=@objdir + Pathname.new("objects") + Pathname.new(@name)
			if( !@objects.exist? )
				@objects.mkpath
			end

		end
		def write_file_block( out, name, ext )
			out.inc << "#{@name}_#{name}+="
			count = 0
			@src.each{|s|
				obj = s.gsub(/\.[a-z][a-z]*/, ext )
				if( count % 2 == 0 )
					out.inc << "\\\n"
				end
				out.inc << "\t$(OBJDIR)/objects/#{@name}/#{obj} "
				count += 1
			}
			out.inc << "\n\n"
		end
		def write_header( out )
			out.inc << "TOPSRC=#{@topsrc}\n"
			out.inc << "include $(TOPSRC)/config/make.config\n"
			out.inc << "#{@name}_CPPFLAGS=#{@cppflags.join(' ')}\n"
			out.inc << "#{@name}_CFLAGS=#{@cflags.join(' ')}\n"
			out.inc << "#{@name}_CXXFLAGS=#{@cxxflags.join(' ')}\n"
			out.inc << "#{@name}_LDFLAGS=#{@ldflags.join(' ')}\n"
			out.inc << "#{@name}_LIBS=#{@libs.join(' ')}\n"
			write_file_block( out, "OBJS", '.$(OBJ_SUFFIX)' ) 
			write_file_block( out, "DEPS", '.d' ) 
			write_clean( out )
		end

		def write_deps( out )
			
			# add xpidl file to deps
			out.inc << "#{@name}_DEPS+="
			@idlfiles.each{|idl|
				xptfile = get_xptfile( idl )
				header = get_header( idl )
				out.inc << "#{@install}/#{xptfile} #{header} "
			}
			out.inc << "\n"

			# add all c++ dependency files to Makefile
			@src.each{|s|
				dep = s.gsub(/\.[a-z][a-z]*/, ".d" )
				out.mkfile << "-include $(OBJDIR)/objects/#{@name}/#{dep}\n"
			}

			# add external target dependencies to stub file and inc file
			out.inc << "#{@name}_DEPS+="

			@deps.each{ |dep|
				if( $targets.has_key?( dep ) )
					target = $targets[dep]
					if( target != self )
						path2target = target.path.relative_path_from(@path)
						out.inc << "#{path2target}/#{target.target} "
						if( path2target.to_s != "." )
							target_dep_rule = "#{path2target}/#{target.target}:\n\t$(MAKE) -C #{path2target}\n"
							# only include dep target rules once
							if( !out.target_dep_rules.include?( target_dep_rule ) )
								out.target_dep_rules << target_dep_rule 
								out.rules << target_dep_rule
							end
						end
					end
				else
					STDERR.printf( "Failed to find #{@name} dependency: #{dep}\n" )
				end
			}
			out.inc << "\n"
			@deps.each{ |dep|
				if( $targets.has_key?( dep ) )
					target = $targets[dep]
					path2target = target.path.relative_path_from(@path)
					puts "Target #{@name} has Dependency #{dep}"
					# add include and linker path to cppflags, ldflags, and libs
					out.inc << "#{@name}_CPPFLAGS+= -I#{path2target}\n"
					# XXX: use the target object to write these dependencies target.
					out.inc << "#{@name}_LDFLAGS+= #{target.target_dep_libs(path2target)}\n"
				else
					STDERR.printf( "Failed to find #{@name} dependency: #{dep}\n" )
				end
			}


		end

		def get_xptfile( idl )
			xptfile = idl.gsub(/\.[a-z][a-z]*$/, '.xpt' )
			xptfile = Pathname.new(xptfile).basename
		end
		def get_header( idl )
			header = idl.gsub(/\.[a-z][a-z]*$/, '.h' )
			header = Pathname.new(header).basename
		end
		def get_idl_path( idl )
			Pathname.new(idl).dirname
		end

		def write_rules( out )
			@src.each{|s|
				obj = s.gsub(/\.[a-z][a-z]*$/, '.$(OBJ_SUFFIX)' )
				dep = s.gsub(/\.[a-z][a-z]*$/, '.d' )
				out.rules << "$(OBJDIR)/objects/#{@name}/#{obj}:#{s}\n"
				if( s =~ /\.c$/ )
					write_cc_rule( out )
					out.rules << "$(OBJDIR)/objects/#{@name}/#{dep}:#{s}\n"
					write_cc_dep_rule( out )
				elsif( s =~ /\.cc$|\.cpp$|\.cxx$/ )
					write_cxx_rule( out )
					out.rules << "$(OBJDIR)/objects/#{@name}/#{dep}:#{s}\n"
					write_cxx_dep_rule( out )
				end
			}
			@idlfiles.each{|idl|
				xptfile = get_xptfile( idl )
				header = get_header( idl )
				out.rules << "#{header}: #{idl}\n"
				out.rules << "\techo \"(XPIDL) $@\"; $(MOZ_DIST)/bin/xpidl -w -v -e $@ -m header -I#{get_idl_path(idl)} -I. -I$(MOZ_DIST)/idl $<\n"
				out.rules << "#{@install}/#{xptfile}: #{idl}\n"
				out.rules << "\techo \"(XPIDL) $@\"; $(MOZ_DIST)/bin/xpidl -a -w -v -e $@ -m typelib -I#{get_idl_path(idl)} -I. -I$(MOZ_DIST)/idl $<\n"
			}
		end
		def get_echo()
			if( @os == "win32" )
				"echo -n"
			else
				"echo"
			end
		end
		def write_cxx_rule( out )
			if( @explicitcc != "" ) 
				out.rules << "\t#{get_echo} \"(CXX) `basename '$@'` \"; #{@explicitcc} "
				out.rules << "$(#{@name}_CPPFLAGS) $(#{@name}_CXXFLAGS) -c #{@explicitout}$@ $<\n"
			else
				out.rules << "\t#{get_echo} \"(CXX) `basename '$@'` \"; $(CXX) $(CPPFLAGS) $(CXXFLAGS) "
				out.rules << "$(#{@name}_CPPFLAGS) $(#{@name}_CXXFLAGS) -c $(OBJOUT)$@ $(DBGOUT) $<\n"
			end
		end
		def write_cc_rule( out )
			if( @explicitcc != "" ) 
				out.rules << "\t#{get_echo} \"(CC) `basename '$@'` \"; #{@explicitcc} "
				out.rules << "$(#{@name}_CPPFLAGS) $(#{@name}_CFLAGS) -c #{@explicitout}$@ $<\n"
			else
				out.rules << "\t#{get_echo} \"(CC) `basename '$@'` \"; $(CC) $(CPPFLAGS) $(CFLAGS) "
				out.rules << "$(#{@name}_CPPFLAGS) $(#{@name}_CFLAGS) -c $(OBJOUT)$@ $(DBGOUT) $<\n"
			end
		end
		def write_cc_dep_rule( out )
			out.rules << "\techo \"(DEP) `basename '$@'`\"; $(TOPSRC)/tools/dep.rb #{@name} $< $@ "
			out.rules << "$(CPPFLAGS) $(CFLAGS) $(#{@name}_CPPFLAGS) $(#{@name}_CFLAGS) > $@\n"
		end
		def write_cxx_dep_rule( out )
			out.rules << "\techo \"(DEP) `basename '$@'`\"; $(TOPSRC)/tools/dep.rb #{@name} $< $@ "
			out.rules << "$(CPPFLAGS) $(CXXFLAGS) $(#{@name}_CPPFLAGS) $(#{@name}_CXXFLAGS) > $@\n"
		end
		def write( output )
			if( @voidtarget == "true" )
				return
			end
			write_header( output )
			write_rules( output )
		end
		def write_clean( out )
			if( @voidtarget == "true" )
				return
			end
			out.inc << "TARGETS_OBJS += $(#{@name}_OBJS)\n"
			out.inc << "TARGETS_DEPS += $(#{@name}_DEPS)\n"
		end
	end

	# gets each word from an element block
	# for example all the source files from a src block
	# or all the cflags from cflags block
	def self.get_block_items(el,tagName)
		items = []
		el.elements.each(tagName){|element| 
			element.texts.each{|text|
				items += text.to_s.split(' ')
			}
		}
		items
	end

	class CustomTarget < Target
		def initialize(el)

			@inc = ""
			el.elements.each("inc"){|e| 
				e.texts.each{|text| @inc += text.to_s }
			}

			@rule = ""
			el.elements.each("rule"){|e| 
				e.texts.each{|text| @rule += text.to_s }
			}
			
		end

		def write( output )
			output.inc << @inc
			output.rules << @rule
		end

	end

	class CopyTarget < Target
		def initialize(root_path, path, el, opts)
			super
			@root_path = root_path
			@path = path
			@target_path = Build.get_attr(el,"dest")
			@files = []
			el.texts.each{|text|
				@files += text.to_s.split(' ')
			}
		end
		def write( output )
			write_header( output )
			@files.each{ |file|
				output.inc << "TARGETS += #{@target_path}/#{file}\n"
				output.rules << "#{@target_path}/#{file}:#{file}\n"
				output.rules << "\tcp $< $@\n\n"
			}
		end
	end

	class LibraryTarget < Target
		def initialize(root_path, path, el, opts)
			super
			@libpath = "#{@install}"
			@libbase = "#{@libpath}/$(LIB_PREFIX)#{@name}"
		end
		def target
			@libtarget
		end

		def target_dep_libs( path2target )
			if( @noinstall == "true" )
				if( @os == 'win32' )
					"#{path2target}/#{@libbase}.$(STATIC_SUFFIX)"
				else
					"-L#{path2target} -l#{@name}"
				end
			else
				if( @os == 'win32' )
					"#{@libbase}.$(STATIC_SUFFIX)"
				else
					"-L#{@libpath}/ -l#{@name}"
				end
			end
		end

		def write( output )
			super
			if( @voidtarget == "true" )
				return
			end

			output.inc << "TARGETS+=#{@libtarget}\n"
			output.inc << "TARGETS_EXTRA+=#{@extras}\n"
		end
	end

	class StaticLibraryTarget < LibraryTarget
		def initialize(root_path, path, el, opts)
			super
			if( !Build.get_attr(el,"install") && @noinstall != "true" )
				@libpath = "$(OBJDIR)/lib"
				@libbase = "#{@libpath}/$(LIB_PREFIX)#{@name}"
			end
			@libtarget	= "#{@libbase}.$(STATIC_SUFFIX)"
			if( @os == 'win32' )
				@extras = "#{@libbase}.ilk #{@libbase}.pdb"
			end
		end

		def write( output )
			super
			if( @voidtarget == "true" )
				return
			end

			# write main makefile
			output.mkfile << "#{@libtarget}:$(#{@name}_OBJS) $(#{@name}_DEPS)\n"
			if( @os == 'win32' )
				output.mkfile << "\techo \"(LIB) $@\"; lib -nologo -out:$@ "
				output.mkfile << "$(#{@name}_OBJS) \n" #$(#{@name}_LDFLAGS) $(LDFLAGS)  $(#{@name}_LIBS) $(LIBS)\n"
			elsif( @os =~ /linux|macosx/ )
				output.mkfile << "\techo \"(AR) $@\"; ar rs $@ $(#{@name}_OBJS) $(#{@name}_LDFLAGS) $(LDFLAGS)  $(#{@name}_LIBS) $(LIBS)\n"
			end

			# write dependencies
			write_deps( output )

		end
	end

	class SharedLibraryTarget < LibraryTarget
		def initialize(root_path, path, el, opts)
			super
			@libtarget	= "#{@libbase}.$(LIB_SUFFIX)"
			if( @os == 'win32' )
				@extras = "#{@libbase}.exp #{@libbase}.ilk #{@libbase}.pdb #{@libbase}.lib"
			end
		end
		def write( output )
			super
			if( @voidtarget == "true" )
				return
			end

			# write some extra cppflags specific to shared libraries
			if( @os == 'win32' )
				output.inc << "#{@name}_CPPFLAGS += \n" # XXX: Fix this for Win32
			elsif( @os =~ /linux|macosx/ )
				output.inc << "\t#{@name}_CPPFLAGS += -fPIC\n"
			end

			# write main makefile
			output.mkfile << "#{@libtarget}: $(#{@name}_DEPS) $(#{@name}_OBJS) \n"
			if( @os == 'win32' )
				output.mkfile << "\techo \"(LD) $@\"; $(LD) -DLL -out:$@ -implib:#{@libbase}.lib "
				if( !@def.empty? )
					output.mkfile << "-def:#{@def} "
				end
				output.mkfile << "$(#{@name}_OBJS) $(#{@name}_LDFLAGS) $(LDFLAGS)  $(#{@name}_LIBS) $(LIBS)\n"
			elsif( @os =~ /macosx/ )
				output.mkfile << "\techo \"(LD) $@\"; $(LD) -dynamiclib -o $@ $(#{@name}_OBJS) $(#{@name}_LDFLAGS) $(LDFLAGS)  $(#{@name}_LIBS) $(LIBS)\n"
			elsif( @os =~ /linux/ )
				output.mkfile << "\techo \"(LD) $@\"; $(LD) -shared -o $@ $(#{@name}_OBJS) $(#{@name}_LDFLAGS) $(LDFLAGS)  $(#{@name}_LIBS) $(LIBS)\n"
				output.mkfile << "\techo \"(LDD) -r $@\";\n"
				output.mkfile << "\texport LD_LIBRARY_PATH=#{@install}:#{@loadpath}:$(LD_LIBRARY_PATH); \\\n"
				output.mkfile << "if ( ldd -r #{@libtarget} 2>&1 | grep 'undefined symbol' ); then exit 1; fi\n\n"
			end

			# write dependencies
			write_deps( output )

		end
	end

	class BinTarget < Target
		def initialize(root_path, path, el, opts)
			super
			if( @noinstall == "true" )
				@binbase = "#{@name}"
			else
				@binbase = "$(OBJDIR)/bin/#{@name}"
			end
			@bintarget = "#{@binbase}$(BIN_SUFFIX)"
			if( @os == 'win32' )
				@extras = "#{@binbase}.ilk #{@binbase}.pdb"
			end
		end
		def target
			@bintarget
		end
		def write( output )
			super
			if( @voidtarget == "true" )
				return
			end
			output.inc << "TARGETS+=#{@bintarget}\n"
			output.inc << "TARGETS_EXTRA+=#{@extras}\n"

			resdeps = []
			if( @os == 'win32' )
				# write rule for rc files
				@resources.each{|res|
					tres = res.gsub( /\.rc$/, ".res" )
					tres = "$(OBJDIR)/objects/#{@name}/#{tres}"
					resdeps << tres
					output.inc << "#{@name}_DEPS+=#{tres}\n"
					output.rules << "#{tres}: #{res}\n"
					output.rules << "\trc /r /fo$@ $<"
				}
			end

			# write main makefile
			output.mkfile << "#{@bintarget}:$(#{@name}_DEPS) $(#{@name}_OBJS) "
			if( @explicitld != "" ) 
				output.mkfile << "\n\t#{@explicitld} #{@explicitldout} $@ $(#{@name}_OBJS) $(#{@name}_LDFLAGS) $(#{@name}_LIBS)\n"
			elsif( @os == 'win32' )
				resdeps.each{|res|
					output.mkfile << "#{res} "
				}
			#	@deps.each{ |dep|
			#		if( $targets.has_key?( dep ) )
			#			target = $targets[dep]
			#			output.mkfile << "#{target.target} "
			#			path2target = target.path.relative_path_from(@path)
			#			output.inc << "#{@name}_LIBS += #{target.target_dep_libs(path2target)}\n"
			#		else
			#			STDERR.printf( "Failed to find #{@name} dependency: #{dep}\n" )
			#		end
			#	}
				output.mkfile << "\n\techo \"(LD) $@\"; $(LD) -out:$@ "
				if( @def && !@def.empty? )
					output.mkfile << "-def:#{@def} "
				end
				output.mkfile << "$(#{@name}_OBJS) $(#{@name}_LDFLAGS) $(LDFLAGS)  $(#{@name}_LIBS) $(LIBS) "
				resdeps.each{|res|
					output.mkfile << "#{res} "
				}
				output.mkfile << "\n"
			elsif( @os =~ /linux|macosx/ )
				output.mkfile << "\n\techo \"(LD) $@\"; $(LD) -o $@ $(#{@name}_OBJS) $(#{@name}_LDFLAGS) $(LDFLAGS)  $(#{@name}_LIBS) $(LIBS)\n"
			end

			write_deps( output )
		end
	end

	def self.create_rule(path,file)
	end

	class Rule
	end

	class TypelibRule < Rule
		def initialize(path,el, opts=nil)
			@idl_file = Build.get_attr(el,"idl")
			@xpt_file = Build.get_attr(el,"xpt")
			@dep_stub = Build.get_attr(el,"dep")
			@opts = opts
		end

		def write( output )
			if @opts.os == "win32"
				write_win32( output )
			else
				write_other( output )
			end
		end
		def write_win32( output )
		end
		def write_other( output )
		end
	end

	# generates a make rule for a C file
	class CObjectRule < Rule
		def initialize(path,el, opts)
		end
		def write( output )
		end
	end

	# generates a make rule for a C++ file
	class CPPObjectRule < Rule
		def initialize(path,el, opts)
		end
		def write( output )
		end
	end

	# generates a make rule to copy a file
	class CopyRule < Rule
		def initialize(path,el, opts)
		end
		def write( output )
		end
	end

	# generates a make rule execute some sql
	class SQLTarget < Target
		def initialize(path,el, opts)
		end
		def write( output )
		end
	end

	def self.prepare( root_path, conf_file, opts )

		$targets = Hash.new # global store of all targets for resolving inter target dependencies

		pp "Targeting: #{opts.flags['config']['OS_ARCH']}"
		ignore_files = {}
		ignore_folder =  "config/ignore_folders"

		if( FileTest.exists?(ignore_folder) )
			File.open(ignore_folder) {|file|
				while line = file.gets
					ignore_files[line.chomp] = true
				end
			}
		end

		makefiles = []

		root_path = Pathname.new(root_path).realpath 
		puts "Source Root: #{root_path.to_s}"
		printf "Scanning: "
		Find.find( root_path ) do |path|
			if( FileTest.directory?(path) )
				base_name = File.basename(path)
				if( base_name[0] == ?. || ignore_files.has_key?(base_name) )
					Find.prune       # Don't look any further into this directory.
				else
					p = (Pathname.new(path) + conf_file).to_s
					if( FileTest.exists?(p) )
						Find.find( p ) do |conf|
							printf "."
							makefiles << Makefile.new( root_path, conf, opts )
						end
						STDOUT.flush
					end
					next
				end
			end
		end

		puts "\n"
		#printf "\nFound #{makefiles.size} Files\n"
		makefiles
	end

	def self.commit( makefiles )
		makefiles.each{ |makefile|
			makefile.write
			puts "Creating: #{makefile.path + 'Makefile'}\n"
			STDOUT.flush
		}
		printf "\n"

	end

end
