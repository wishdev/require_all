#--
# Copyright (C)2009 Tony Arcieri
# You can redistribute this under the terms of the MIT license
# See file LICENSE for details
#++

module RequireAll
  # Load all files matching the given glob, handling dependencies between
  # the files gracefully
  # One of the easiest ways to require_all is to give it a glob, which will 
  # enumerate all the matching files and load them in the proper order. For 
  # example, to load all the Ruby files under the 'lib' directory, just do:
  #
  #  require_all 'lib/**/*.rb'
  #
  # If the dependencies between the matched files are unresolvable, it will 
  # throw the first unresolvable NameError.
  #
  # Don't want to give it a glob?  Just give it a list of files:
  #
  #  require_all Dir.glob("blah/**/*.rb").reject { |f| stupid_file(f) }
  # 
  # Or if you want, just list the files directly as arguments:
  #
  #  require_all 'lib/a.rb', 'lib/b.rb', 'lib/c.rb', 'lib/d.rb'
  #
  # It's just that easy!  Code loading shouldn't be hard, especially in a language
  # as versatile as ruby.
  def require_all(*args)
    # Handle passing an array as an argument
    args = args.flatten
    
    if args.size > 1
      # If we got a list, those be are files!
      files = args
    else
      arg = args.first
      begin
        # Try assuming we're doing plain ol' require compat
        File.stat(arg)
        files = [arg]
      rescue Errno::ENOENT
        # If the stat failed, maybe we have a glob!
        files = Dir.glob arg
        
        # If we ain't got no files, the glob failed
        raise LoadError, 'no such file to load -- #{arg}' if files.empty?
      end
    end
    
    files.map! { |file| File.expand_path file }
            
    begin
      failed = []
      first_name_error = nil
      
      # Attempt to load each file, rescuing which ones raise NameError for
      # undefined constants.  Keep trying to successively reload files that 
      # previously caused NameErrors until they've all been loaded or no new
      # files can be loaded, indicating unresolvable dependencies.
      files.each do |file|
        begin
          require file
        rescue NameError => ex
          failed << file
          first_name_error ||= ex
        rescue ArgumentError => ex
          # Work around ActiveSuport freaking out... *sigh*
          #
          # ActiveSupport sometimes throws these exceptions and I really
          # have no idea why.  Code loading will work successfully if these
          # exceptions are swallowed, although I've run into strange 
          # nondeterministic behaviors with constants mysteriously vanishing.
          # I've gone spelunking through dependencies.rb looking for what 
          # exactly is going on, but all I ended up doing was making my eyes 
          # bleed.
          #
          # FIXME: If you can understand ActiveSupport's dependencies.rb 
          # better than I do I would *love* to find a better solution
          raise unless ex.message["is not missing constant"]
          
          STDERR.puts "Warning: require_all swallowed ActiveSupport 'is not missing constant' error"
          STDERR.puts ex.backtrace[0..9]
        end
      end
      
      # If this pass didn't resolve any NameErrors, we've hit an unresolvable
      # dependency, so raise one of the exceptions we encountered.
      if failed.size == files.size
        raise first_name_error
      else
        files = failed
      end
    end until failed.empty?
    
    true
  end
end

include RequireAll