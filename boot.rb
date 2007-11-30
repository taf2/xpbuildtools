#!/usr/bin/env ruby

# Called by boot.sh, this script does a lot of the work of 
# setting up everything, and propogating settings like 
# brand, revision, stuff like that.  

require 'erb'
require 'yaml'
require 'rbconfig'
require 'find'
require 'fileutils'
require 'optparse'
require 'ostruct'
require 'tools/pathname.rb'
require 'tools/build.rb'
require 'rubygems'
require_gem 'uuidtools'

class BuildConfig
	attr_reader :opts

	def self.clean_str( s )
		s = s.strip
		s = s.squeeze("\t ")
		s
	end

	def short_platform
		case PLATFORM
			when /darwin/i
				"darwin"
			when /win32|cygwin/i
				"win32"
			when /linux/i
				"linux"
			else
				"unknown"
		end
	end

	# initialize the configuration
	# parse commandline arguments and
	# detect the OS
	def initialize(args)
		@opts = OpenStruct.new
		# setup the defaults
		@opts.path = Pathname.new(".").realpath.to_s
		@opts.brand = "simo"
		@opts.mode = "debug"
		@opts.ignore = ""
		@opts.os = PLATFORM

		target = short_platform

		@opts.flags = YAML.load_file( "config/#{target}.yml" )

		overridedefault=false
		mozdist = ''
		firedist =''
		opts = OptionParser.new { |opts|
			opts.banner = "Usage: #{$0} [options]"
			opts.separator ""
			opts.separator "Specific options:"

			opts.on( "-b S", "--brand", "Brand to Build" ){|brand| @opts.brand = BuildConfig.clean_str( brand ) }
			opts.on( "-m S", "--mode", "Mode to Build (release|debug)" ) { |mode| @opts.mode = BuildConfig.clean_str( mode ) }
			opts.on( "-x S", "--xul", "Path to your Mozilla Dist Folder" ){ |xul| 
				mozdist = "'#{BuildConfig.clean_str( xul )}'"
				overridedefault=true
			}
			opts.on( "-d S", "--database", "Firebird Database Binaries" ) { |fdb|
				firedist = "'#{BuildConfig.clean_str( fdb )}'"
				overridedefault=true
			}

			opts.separator ""
			opts.separator "Common options:"

			# No argument, shows at tail.  This will print an options summary.
			# Try it and see!
			opts.on_tail("-h", "--help", "Show this message") {
				puts opts
				exit
			}

			opts.on_tail("--version", "Show version") {
				puts "0.1"
				exit
			}
			opts.on_tail("--info", "Detail about your host build environment") {
				print_config
				exit
			}
		}.parse!

		if overridedefault == true

			if mozdist != ''
				if !@user_opts
					@user_opts = Hash.new
				end
				if !@user_opts[@opts.mode]
					@user_opts[@opts.mode] = Hash.new
				end
				@user_opts[@opts.mode]['MOZDIST'] = mozdist
			end

			if firedist != ''
				if !@user_opts
					@user_opts = Hash.new
				end
				if !@user_opts[@opts.mode]
					@user_opts[@opts.mode] = Hash.new
				end
				@user_opts[@opts.mode]['FIREBIRDDIST'] = firedist
			end

			puts "Creating user config YAML File"
			File.open( "config/user_#{target}.yml", "w" ){ |out| YAML.dump( @user_opts, out ) }
			@user_opts = YAML.load_file( "config/user_#{target}.yml" )
		end
		
		@user_opts = YAML.load_file( "config/user_#{target}.yml" )

		# XXX: gotta love rubys win32 support
		mozdist = @user_opts[@opts.mode]['MOZDIST'].gsub("'","").strip.gsub('\\','/').gsub('C:/','c:/')
		firedist = @user_opts[@opts.mode]['FIREBIRDDIST'].gsub("'","").strip.gsub('\\','/').gsub('C:/','c:/')
		puts "#{mozdist}"

		# need to make this path relative to the source dir
		mozdist = Pathname.new( mozdist )
		if( mozdist.absolute? )
			mozdist = mozdist.relative_path_from( Pathname.new(@opts.path) )
			if( target == "win32" )
				mozdist = Pathname.new( mozdist.to_s.gsub('c:/','') )
			end
		end
		firedist = Pathname.new( firedist )
		if( firedist.absolute? )
			firedist = firedist.relative_path_from( Pathname.new(@opts.path) )
			if( target == "win32" )
				firedist = Pathname.new( firedist.to_s.gsub('c:/','') )
			end
		end
		puts "mozdist: #{mozdist}"
		puts "firedist: #{firedist}"
		@user_opts[@opts.mode]['MOZDIST'] = mozdist
		@user_opts[@opts.mode]['FIREBIRDDIST'] = firedist
		#File.open( "config/user_#{target}.yml", "w" ){ |out| YAML.dump( @user_opts, out ) }

	end

	def print_config
		puts "Brand: [#{@opts.brand}]"
		puts "Mode: [#{@opts.mode}]"
		@opts.flags['config'].each{|flag,value|
			puts "#{flag}: #{value}\n"
		}
	end

	def get_binding
		binding
	end

	def prepare_chrome_manifest

		# if chrome.manifest file exists in brand directory, use it, else generate it
		manifest_file = "brand/" + @opts.brand + "/chrome.manifest." + @opts.mode
		puts "manifest_file: #{manifest_file}"
		if (File.exists?(manifest_file))
			FileUtils.cp( manifest_file, @chrome + "chrome.manifest" )		
		else
			if( @opts.mode == "release" )
				@simo_chrome = "jar:simo.jar!/content/"
				@simo_skin = "jar:simo.jar!/skin/"
				@simo_brand = "jar:simo.jar!/brand/#{@opts.brand}/"
				@simo_locale = "jar:simo.jar!/locale/en-US/"
				@simo_default = "jar:simo.jar!/locale/"
			else
				@simo_chrome = "../../../chrome/"
				@simo_skin = "../../../skin/"
				@simo_brand = "../../../brand/#{@opts.brand}/"
				@simo_locale = "../../../locale/en-US/"
				@simo_default = "../../../locale/"
			end

			# write the chrome.manifest file
			erb = ERB.new(File.open("chrome.manifest.rb","r").read,0, "<>")
			File.open(@chrome + "chrome.manifest","w").write( erb.result( self.get_binding ) )
		end
		
		# build the jar file
		if( @opts.mode == "release" )
			puts "calling config/scripts/buildjar.sh"
			if @opts.os =~ /mswin32/
				real_objdir = @objdir.realpath
				ret = system( "build.bat #{@opts.path}/config/scripts/buildjar.sh #{real_objdir} #{@opts.brand}" )
			else
				ret = system( "bash config/scripts/buildjar.sh #{@objdir} #{@opts.brand}" )
			end
			if( !ret )
				puts "System Error: #{$?}"
				exit 1
			end
			puts "called config/scripts/buildjar.sh"
		end

	end

	def prepare_xulrunner

		mozdist = Pathname.new( @user_opts[@opts.mode]['MOZDIST'] )
		ext=""
		if( @opts.os =~ /cygwin|mswin/ )
			ext=".exe"
		end

		if( @opts.os =~ /cygwin|mswin|linux/ )
			#FileUtils.cp( mozdist + "bin" + "xulrunner-stub#{ext}", @objdir + "bin" + "simo#{ext}" )
			xulrunner=@objdir + "bin" + "xulrunner"
			if( !xulrunner.exist? )
				pp "Installing XULRunner into #{@objdir + "bin" + "xulrunner"}"
				if( @opts.os =~ /mswin/ )
					FileUtils.cp_r( mozdist + "bin/.", xulrunner )
				else
					system( "cp -RL #{(mozdist + "bin/.").to_s} #{xulrunner.to_s}" )
				end
				if( @opts.os =~ /cygwin|mswin/ )
					FileUtils.mv( xulrunner + "xulrunner.exe", xulrunner + "simo-bin.exe" )
				#elsif( @opts.os =~ /linux/ )
				#	FileUtils.mv( xulrunner + "xulrunner", xulrunner + "simo-bin" )
				end
			end
		end

		if( @opts.os =~ /cygwin|mswin/ )
			firebird = Pathname.new( @user_opts[@opts.mode]['FIREBIRDDIST'] )
			if( firebird != "" )
				udfdir = @objdir + "bin" + "xulrunner" + "udf"
				if( !udfdir.exist? )
					udfdir.mkpath
					fbudf = firebird + "udf"
					fbbin = firebird + "bin"
					FileUtils.cp( fbudf + "fbudf.dll", udfdir )
					FileUtils.cp( fbudf + "ib_udf.dll", udfdir )
					FileUtils.cp( fbbin + "ib_util.dll", @objdir + "bin" + "xulrunner" )
					FileUtils.cp( fbbin + "fbembed.dll", @objdir + "bin" + "xulrunner" )
					FileUtils.cp( firebird + "firebird.msg", @objdir + "bin" + "xulrunner" )
				end
			end
		elsif @opts.os =~ /linux/ && !( @objdir + "bin" + "xulrunner" + "bin" + "fb_lock_mgr" ).exist?
			firebird = Pathname.new( "firebird/linux" )
			FileUtils.cp( firebird + "firebird.conf", @objdir + "bin" + "xulrunner" )
			if( !( @objdir + "bin" + "xulrunner" + "bin" ).exist? ) 
				FileUtils.mkdir( @objdir + "bin" + "xulrunner" + "bin" )
			end
			FileUtils.cp( firebird + "bin" + "fb_lock_mgr", @objdir + "bin" + "xulrunner" + "bin" )
			FileUtils.cp( firebird + "firebird.msg", @objdir + "bin" + "xulrunner" )
			FileUtils.cp( firebird + "libfbembed.so.1.5.3", @objdir + "bin" + "xulrunner" )
			FileUtils.cp( firebird + "libib_util.so", @objdir + "bin" + "xulrunner" )
			FileUtils.cp( firebird + "security.fdb", @objdir + "bin" + "xulrunner" )
			if( !(  @objdir + "bin" + "xulrunner" + "intl" ).exist? )
				FileUtils.mkdir( @objdir + "bin" + "xulrunner" + "intl" )
			end
			FileUtils.cp( firebird + "intl" + "fbintl", @objdir + "bin" + "xulrunner" + "intl" )
		elsif @opts.os =~ /darwin/
			contents = Pathname.new("SimoHealth.app/Contents").realpath
			bindir = Pathname.new(@objdir + "bin").realpath
			xulframework = Pathname.new( mozdist + "XUL.framework" ).realpath
			if( (contents + "Frameworks/XUL.framework").exist? )
				FileUtils.rm(contents + "Frameworks/XUL.framework")
			end
			# remove the links
			FileUtils.rm( contents + "Frameworks/XUL.framework", :force => true )
			FileUtils.rm( contents + "Frameworks/Firebird.framework", :force => true )
			# add the links
			FileUtils.ln_sf(xulframework, contents + "Frameworks/XUL.framework" )
			FileUtils.ln_sf("/Library/Frameworks/Firebird.framework/", contents + "Frameworks/Firebird.framework" )
			FileUtils.cp( mozdist + "bin" + "xulrunner", contents + "MacOS" )
			if( (contents + "Resources").exist? )
				FileUtils.rm(contents + "Resources")
			end
			FileUtils.ln_sf( bindir, contents + "Resources" )
		end
	end

	# create all the little files here and there that  the app needs
	def prepare_application
		@simo_version = YAML.load_file( "config/simo_version.yml" )

		# create the application.ini file
		erb = ERB.new(File.open("application.ini","r").read, 0, "<>")
		File.open((@objdir + "bin" + "application.ini"),"w").write( erb.result( self.get_binding ) )
		
		# create the appinfo.xml file
		index = YAML.load_file( "config/brand.yml" )
		@pretty_brand = index['brands'][@opts.brand]

    if File.exist?(".svn/dir-wcprops")
      @code_revision = File.new( ".svn/dir-wcprops" ).readlines[-2].match( "[0-9]+" )
    elsif File.exists?(".svn/all-wcprops")
      @code_revision = File.new( ".svn/all-wcprops" ).readlines[-2].match( "[0-9]+" )
    else
      puts "#{__FILE__}:#{__LINE__} Not sure where to get your subversion dir props"
    end
		#system( "svn info | grep -i 'Last Changed Rev:' | grep -Eo [0-9]+" )

		# create the simo_version.h file
		svh = File.open("components/firebird/simoVersion.h", "w")
		svh.write("// File generated by boot.sh - DO NOT EDIT!\n")
		svh.write("#define SIMO_VERSION  \"#@simo_version\"\n")
		svh.write("#define SIMO_REVISION #@code_revision\n")
		svh.close
		
		@appid = ( @opts.mode == "release" ) ? "release" : UUID.random_create.to_s
		# system("uuidgen")
		puts "Simo Version: #@simo_version"
		puts "Code Revision: #{@code_revision}"
		puts "Unique AppId: #{@appid}"
		@platform = short_platform
		erb = ERB.new(File.open("appinfo.xml.in","r").read, 0, "<>")
		appinfo_path = @objdir + "bin" + "appinfo.xml"
		File.open(appinfo_path,"w").write( erb.result( self.get_binding ) )

		# copy the prefs file
		prefdir = @objdir + "bin" + "defaults" + "preferences"
		prefdir.mkpath unless prefdir.exist?
		erb = ERB.new(File.open("defaults/preferences/prefs.js","r").read, 0, "<>")
		File.open((@objdir + "bin" + "defaults" + "preferences" + "prefs.js"),"w").write( erb.result( self.get_binding ) )

		# setup the brand and mode files for the start-simo.sh script
		File.new("config/brand","w").write( @opts.brand )
		File.new("config/mode","w").write( @opts.mode )

		if( @opts.os =~ /cygwin|mswin/ )
			# make sure msvc runtime libraries are installed
			FileUtils.cp( "firebird/msvcp71.dll", @objdir + "bin" )
			FileUtils.cp( "firebird/msvcr71.dll", @objdir + "bin" )
			# install the app icons
			icondir = @objdir + "bin" + "chrome" + "icons" + "default"
			icondir.mkpath unless icondir.exist?
			FileUtils.cp( "icons/simo-window.ico", icondir )
		#elsif( @opts.os =~ /darwin/ )
			#FileUtils.ln_sf( "/Library/Frameworks/Firebird.framework/Versions/Current/Resources/English.lproj/", @objdir + "bin" + "English.lproj" )
		end
	end

	# walk the directory tree locating each Makefile
	def prepare

		# ensure the chrome dir exists
		@objdir = Pathname.new(@opts.mode + "-" + @opts.brand)
		@chrome = @objdir + "bin" + "chrome"
		@chrome.mkpath unless @chrome.exist?
		@components = @objdir + "bin" + "components"
		@components.mkpath unless @components.exist?
		@libdir = @objdir + "lib"
		@libdir.mkpath unless @libdir.exist?

		prepare_chrome_manifest
		prepare_xulrunner
		prepare_application

		# walk dir tree locating mk.conf files creating all makefiles
		@makefiles = Build.prepare( @opts.path, Pathname.new("mk.conf"), @opts )
	end

	# write out all files that including config/make.rules
	# and translate mk.conf to Makefile files
	def commit

		# XXX: have to do this twice :-(
		# need to make this path relative to the source dir
		mozdist = Pathname.new( @user_opts[@opts.mode]['MOZDIST'] )
		if( mozdist.absolute? )
			@user_opts[@opts.mode]['MOZDIST'] = mozdist.relative_path_from( Pathname.new(@opts.path) )
		end
		firedist = Pathname.new( @user_opts[@opts.mode]['FIREBIRDDIST'] )
		if( firedist.absolute? )
			@user_opts[@opts.mode]['FIREBIRDDIST'] = firedist.relative_path_from( Pathname.new(@opts.path) )
		end

		puts "Creating config/make.config"
		puts @user_opts[@opts.mode]['MOZDIST']
		erb = ERB.new(File.open("config/make.erb","r").read,0, "<>")
		File.open("config/make.config","w").write( erb.result( self.get_binding ) )
		Build.commit( @makefiles )
	end

end

conf = BuildConfig.new(ARGV)

conf.print_config

conf.prepare

conf.commit
