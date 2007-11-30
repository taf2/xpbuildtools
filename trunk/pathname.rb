require 'rbconfig'
require 'pathname'

# XXX: these are fixes for win32 ruby 1.8.4
class Pathname

	def absolute?
		if Config::CONFIG['arch'] =~ %r{mswin32}i
			isabs = %r{\A[A-Za-z]:/} =~ @path ? true : false
			#puts "checking [#{@path}] is absolute #{isabs} for os #{Config::CONFIG['arch']}"
		else
			isabs = %r{\A/} =~ @path ? true : false
		end
		isabs
	end

  #
  # Returns a real (absolute) pathname of +self+ in the actual filesystem.
  # The real pathname doesn't contain symlinks or useless dots.
  #
  # No arguments should be given; the old behaviour is *obsoleted*. 
  #
  def realpath(*args)
    unless args.empty?
      warn "The argument for Pathname#realpath is obsoleted."
    end
    force_absolute = args.fetch(0, true)

		# XXX: see http://wiki.rubyonrails.com/rails/pages/Gotcha
    is_absolute = %r{\A/}
		top = '/'
		if Config::CONFIG['arch'] =~ %r{mswin32}i
			is_absolute = %r{\A[A-Za-z]:/}
			top = ''
		end
    if is_absolute =~ @path
      unresolved = @path.scan(%r{[^/]+})
    elsif force_absolute
      # Although POSIX getcwd returns a pathname which contains no symlink,
      # 4.4BSD-Lite2 derived getcwd may return the environment variable $PWD
      # which may contain a symlink.
      # So the return value of Dir.pwd should be examined.
      unresolved = Dir.pwd.scan(%r{[^/]+}) + @path.scan(%r{[^/]+})
    else
      top = ''
      unresolved = @path.scan(%r{[^/]+})
    end
    resolved = []

    until unresolved.empty?
      case unresolved.last
      when '.'
        unresolved.pop
      when '..'
        resolved.unshift unresolved.pop
      else
        loop_check = {}
        while (stat = File.lstat(path = top + unresolved.join('/'))).symlink?
          symlink_id = "#{stat.dev}:#{stat.ino}"
          raise Errno::ELOOP.new(path) if loop_check[symlink_id]
          loop_check[symlink_id] = true
          if %r{\A/} =~ (link = File.readlink(path))
            top = '/'
            unresolved = link.scan(%r{[^/]+})
          else
            unresolved[-1,1] = link.scan(%r{[^/]+})
          end
        end
        next if (filename = unresolved.pop) == '.'
        if filename != '..' && resolved.first == '..'
          resolved.shift
        else
          resolved.unshift filename
        end
      end
    end

    if top == '/'
      resolved.shift while resolved[0] == '..'
    end
    
    if resolved.empty?
      Pathname.new(top.empty? ? '.' : '/')
    else
      Pathname.new(top + resolved.join('/'))
    end
  end
end
