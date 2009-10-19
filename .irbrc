#load gems and wirble
require 'rubygems'
require 'irb/completion'
require 'logger'
# this is kind of stupid ... you have to gem the wirble gem and then send a require 
gem 'wirble'
require 'wirble'
gem 'map_by_method'

#load wirble
Wirble.init
Wirble.colorize

IRB.conf[:AUTO_INDENT]=true

#list of editors for use with editing and opening files, you can re-arrange as to set precedence of what to use
EDITORS = %w{mate jedit} unless Object.const_defined?(:EDITORS)

#inline console logging
@script_console_running = ENV.include?('RAILS_ENV') && IRB.conf[:LOAD_MODULES] && IRB.conf[:LOAD_MODULES].include?('console_with_helpers')
@rails_running = ENV.include?('RAILS_ENV') && !(IRB.conf[:LOAD_MODULES] && IRB.conf[:LOAD_MODULES].include?('console_with_helpers'))
@irb_standalone_running = !@script_console_running && !@rails_running

if @script_console_running && !Object.constants.include?("RAILS_DEFAULT_LOGGER")
  Object.const_set(:RAILS_DEFAULT_LOGGER, Logger.new(STDOUT))
  # require 'active_record'
  # require 'active_record/fixtures'
end

# reloads the irb console can be useful for debugging .irbrc
def reload_irb
  load File.expand_path("~/.irbrc")
  # will reload rails env if you are running ./script/console
  reload! if @script_console_running
  puts "Console Reloaded!"
end

# opens irbrc in textmate
def edit_irb
  `mate ~/.irbrc` if system("mate")
end

# alias for quit
def q; quit; end

#shortcut for y model.column_names
# defaults to piping out to less
# if you need the standard output do :
#   - show :model, :standard
def show(obj=nil,return_type=:less)
  if @irb_standalone_running
    puts "Sorry, this must be used inside script/console"  
  else
    # yes, you can say show :people instead of show Person, no need for the shift key :)
    usage = "USAGE: outputs column names \n alias for: 'y Model.column_names' \n syntax: show Model"
    obj = eval obj.to_s.singularize.camelize if obj.is_a? Symbol
    obj.nil? ? puts(usage) : less(obj.schema(return_type))
  end
end

#shortcut for listing helpers in yaml format
def list_helpers
  @irb_standalone_running ? puts("Sorry, This is only valid in script/console") : y(helper.methods.sort)
end

# determines what editors are available and will open a file in that editor
def open_file_for(file)
  `mate #{file}` if system("mate")
  `gedit #{file}` if system("gedit")
end

# hook for the system's less command allows you to pass in arrays too!
# EX : 
#     less "A bunch of content"
#     less %w(1 2 3) 
#     less [1,2,3]
def less(content)
  content = content.join("\n") if content.is_a?(Array)
  system('echo "' << content << '"|less')
end

# script/console hooks
if @script_console_running
  
  # hook into script/find
  # needs git@github.com:vanntastic/project_search.git
  def find(term=nil)
    msg = "USAGE : find term (hooks into script/find)"
    term.nil? ? puts(msg) : system("./script/find #{term}")
  end
  
  # compiles all the css files into one huge string
  # this is useful when running with less
  # USAGE : all_css.open # => opens the string in less allowing you to search
  def all_css
    css_files = Dir.glob File.join(RAILS_ROOT, "public/stylesheets/","*.css")
    css_content = ""
    css_files.each {|file| css_content << IO.read(file)}
    
    css_content.instance_eval do
      
      # opens with less command
      def open
        less self
        # system('echo "' << self << '"|less')
      end
      
    end
    
    css_content
  end
  
  # == ArHelper Stuff
    # check to see if the ar_helper plugin is installed
    # doesn't work with the new version of ArHelper
    # TODO : might need to adjust this for Rails >= 2.3
    # def ar_helper_exists?; File.exists?("vendor/plugins/ar_helper"); end
    #     
    # def require_and_load_ar_helper
    #     require File.dirname(__FILE__) + '/../vendor/plugins/ar_helper/lib/ar_helper'
    #     # require "vendor/plugins/ar_helper/lib/ar_helper"
    #     extend ArHelper::Sugar if ArHelper.constants.include?("Sugar")
    #     include ArHelper::Sugar if ArHelper.constants.include?("Sugar")
    #     puts "ArHelper::Sugar methods not loaded ... install ArHelper plugin
    #           externally..." unless ArHelper.constants.include?("Sugar")
    # end
    # 
    # if defined? RAILS_GEM_VERSION
    #   require_and_load_ar_helper if ar_helper_exists?
    # end
  # == ArHelper Stuff
  
  #show schema version
  def db_version(just_version=false)
    just_version ? ActiveRecord::Migrator.current_version.to_s : puts("Current version: " + ActiveRecord::Migrator.current_version.to_s)
  end
  
  # standard vi hook with some rails specific helpers
  # USAGE: 
  #   - vi :application, :controller # => opens app/controllers/application.rb
  #   - vi :user, :model # => opens app/models/user.rb
  #   - vi :default, :css # => opens public/stylesheets/default
  #   - vi :application, :helper # => opens app/application_helper
  #   - vi :application, :js # => opens public/javasripts/application.js
  #   - vi "admin/index.rhtml", :view # => opens app/views/admin/index.rhtml
  #   - vi "db/schema.rb" # => opens db/schema.rb
  #   - vi :users, :unit # => opens test/unit/user_test.rb
  #   - vi :users, :functional # => opens test/functional/users_controller_test.rb
  #   - vi :users, :fixture # => opens test/fixtures/users.yml
  # you can also pass in the type argument with a dynamic file name
  # EXAMPLE:
  #   - vi :application_controller # => vi :application, :controller
  #   - vi :users_fixture # => vi :users, :fixture
  # TODO : give this the option of specifying a dir name... 
  #   - vi :create_rjs # => it will look for the first create rjs file
  #   - vi :index_view # => it will look for the first index view file
  def vi(file=nil, type=:any)
    usage = "USAGE: vi [name_of_file], [:type]"
    return usage if file.nil?
    types_to_look_for = %w(controller helper model js rjs css view unit 
                           functional fixture config layout mailer)
    # determine whether or not we can dissect the file parameter                     
    if types_to_look_for.include?(file.to_s.split("_").last)
      file_ary = file.to_s.split("_")
      type = file_ary.delete(file_ary.last).to_sym
      file = file_ary.join("_")
    end
    file_path = vi_file_path_for(type, file)
    file.nil? ? puts(usage) : system("vi #{file_path}")
  end
  
  # dependent on the vi method
  def vi_file_path_for(type,file)
    case type.to_sym
      when :controller
        file = "#{file.to_s}_controller"
        file_path = File.join(RAILS_ROOT, "app/controllers", "#{file.to_s}.rb")
      when :helper
        # let's not exclude the test_helper now
        if file.to_s == "test"
          file_path = File.join(RAILS_ROOT, "test/test_helper.rb")
        else
          file_path = File.join(RAILS_ROOT, "app/helpers", "#{file.to_s}_helper.rb")  
        end
      when :model
        file = file.to_s.singularize
        file_path = File.join(RAILS_ROOT, "app/models", "#{file.to_s}.rb")
      when :js  
        file_path = File.join(RAILS_ROOT, "public/javascripts", "#{file.to_s}.js")
      when :rjs
        file_ary = Dir.glob(File.join("app/views","**","#{file}.rjs"))
        file_path = File.join(RAILS_ROOT, file_ary.first)
      when :css
        file_path = File.join(RAILS_ROOT, "public/stylesheets", "#{file.to_s}.css")  
      when :view
        file_ary = Dir.glob(File.join("app/views","**","#{file}.rhtml"))
        file_path = File.join(RAILS_ROOT, "app/views/#{file_ary.first}")  
      when :unit
        file_path = File.join(RAILS_ROOT, "test/unit/#{file.to_s}_test.rb")
      when :functional
        file_path = File.join(RAILS_ROOT, "test/functional/#{file.to_s}_controller_test.rb")  
      when :fixture
        file_path = File.join(RAILS_ROOT, "test/fixtures/#{file.to_s}.yml")  
      when :config
        file_path = File.join(RAILS_ROOT, "config/#{file.to_s}.rb")
      when :layout
        file_path = File.join(RAILS_ROOT, "app/views/layouts/#{file.to_s}.rhtml")  
        file_path = File.join(RAILS_ROOT, 
        "app/views/layouts/#{file.to_s}.html.erb") if !File.exists?(file_path)
      when :mailer
        file_path = File.join(RAILS_ROOT, "app/models/#{file.to_s}_mailer.rb")
      else
        file_path = File.join(RAILS_ROOT, file)  
    end
    return file_path
  end
  
  # vi_css will open up a css file with vi command which will 
  # allow you to easily browse the stylesheet
  # EXAMPLE : vi_css :default # => opens the stylesheet for default.css
  def vi_css(css_file=nil)
    # css_file.nil? ? p("USAGE : css_for :css_filename") : system("less #{RAILS_ROOT}/public/stylesheets/#{css_file.to_s}.css")
    css_file.nil? ? p("USAGE : vi_css :css_filename") : system("vi #{RAILS_ROOT}/public/stylesheets/#{css_file.to_s}.css")
  end
  
  # vi_js will open up a js file with the vi command which will 
  # allow you to easily browse the javascript file
  # EXAMPLE : vi_js :default # => opens the stylesheet for default.css
  def vi_js(js_file=nil)
    # js_file.nil? ? p("USAGE : js_for :js_filename") : system("less #{RAILS_ROOT}/public/javascripts/#{js_file.to_s}.js")
    js_file.nil? ? p("USAGE : vi_js :js_filename") : system("vi #{RAILS_ROOT}/public/javascripts/#{js_file.to_s}.js")
  end
  
  # Run a simple sql query when you need it
  # http://ozmm.org/posts/railsrc.html
  def sql(query)
    ActiveRecord::Base.connection.select_all(query)
  end 
  
  # hooks into the Object#fixture and helper methods
  # USAGE : 
  # say we want to operate on a User model/domain: 
  #   - user # => shows the schema
  #   - users # => shows the fixture keys
  #   - users :keys # => gets the fixture keys
  #   - user_keys # => gets the fixture keys
  #   - users :vann # => gets the Fixture key as an AR Object
  #   - user_fixtures # => prints the fixtures for users
  #   - user_f # => prints the fixtures for users
  #   - user_fixtures :vann # => prints the fixtures key for vann
  #   - user_model # => pulls up the user model in vi
  #   - user_m # => alias for user_model
  #   - users_controller # => pulls up the users controller in vi
  #   - users_c # => alias for users_controller
  # inspired by : http://ozmm.org/posts/railsrc.html
  def method_missing(method, *args, &block)
    # check to see if you are passing a call to the fixture method
    method_array = method.to_s.split("_")
    available_model_calls = %w(model m)
    available_controller_calls = %w(controller c)
    available_fixture_calls = %w(fixtures fixture f)
    # all standard extensions that you can use to hook vi calls into
    available_vi_calls = %w(js css helper config 
                            func functional unit layout mailer)
    available_spec_calls = %(spec)                        
    if available_fixture_calls.include?(method_array.last)
      # sanitizes the array of the 'fixture' || 'f' strings this allows you to pass things 
      # like user_log_fixture or history_log_fixture or super_cool_log_table_fixture
      method_array.delete_if {|m| (m =~ /fixture/).is_a? Fixnum}
      method_array.delete_if {|m| (m =~ /f/).is_a? Fixnum}
      model = eval(method_array.join("_").singularize.camelize)
      model.send(:fixture, *args)
    elsif method_array.include?("keys") 
      # opens the fixture keys for said model
      method_array.delete_if {|m| (m =~ /keys/).is_a? Fixnum}
      model = eval(method_array.join("_").singularize.camelize)
      model.send(:keys, *args)
    elsif available_vi_calls.include?(method_array.last)
      vi(method.to_sym)
    elsif available_model_calls.include?(method_array.last)
      # pulls up said model in vi
      method_array.delete_if {|m| available_model_calls.include?(m) }
      model_name = method_array.join("_")
      vi_call = "#{model_name}_model".to_sym
      vi(vi_call)
    elsif available_controller_calls.include?(method_array.last)
      # pulls up said controller in vi
      method_array.delete_if {|m| available_controller_calls.include?(m) }
      controller_name = method_array.join("_")
      vi_call = "#{controller_name}_controller".to_sym
      vi(vi_call)
    elsif available_spec_calls.include?(method_array.last)
      method_array.pop # => removes 'spec'
      spec_type = method_array.last
      method_array.pop # => removes the 'spec type'
      spec_name = method_array.join("_")
      spec(spec_type.to_sym, spec_name.to_sym, *args)
    else
      # convention over configuration at it's finest
      # user # => shows the user model and relationships
      # users # => shows the keys in the users fixtures
      # users(:vann) # => finds vann for you and returns User for quick testing similar to what you get in Test::Unit
      model_to_eval = method.to_s
      singular_model = method.to_s.singularize
      pluralar_model = method.to_s.pluralize
      model = eval(singular_model.camelize)
      if model_to_eval == pluralar_model
        args << :keys if args.blank?
      end
      # you can pass user :keys # => User.keys (fixture keys) or
      # you can pass user :vann # => User.f(:vann) # => pulls the fixture into a model
      args.blank? ? show(model) : (args.include?(:keys) ? model.send(:keys) : model.send(:f,*args))
    end
  # TODO : have this delegate to the real error perhaps have it eval model? lowercase... learn how to pass in the argument...
  rescue NameError => trace
    raise NameError, "The method/variable that you typed doesn't exist\n" + trace
  end
  
  # system hook into cheat piped through less
  def cheat(arg="")
    system("cheat #{arg.to_s} | less")
  end
  
  # test/spec hooks
  def spec(type=nil,file=nil,test_name=nil)
    msg = "spec is a hook that runs your test/spec tests\n"
    msg << "==\n"
    msg << "spec [:unit,:func||:functional,:all,:plugin], [:file], [:name_of_spec]"
    spec_types = [:unit,:func,:functional,:all,:plugin, :controller]
    if ( !spec_types.include?(type) || (type.nil? && file.nil?))
      puts msg
    else
      status = "Running specs for #{file.to_s} [#{type.to_s}]"
      status << ": on '#{test_name.to_s}'" unless test_name.nil?
      status << "... please wait..."
      puts status
      type = :func if (type == :functional || type == :controller)
      case type
        when :unit
          test_cmd = "specrb -as test/unit/#{file.to_s}_test.rb"
        when :func 
          test_cmd = "specrb -as test/functional/#{file.to_s}_controller_test.rb"
        when :plugin
          path = File.join RAILS_ROOT, 
                "vendor/plugins/#{file.to_s}/test/#{file.to_s}_test.rb"
          test_cmd = "specrb -as #{path}"
        when :all
          system("rake spec") 
      end  
      
      # runs said spec commands and appends a name if given
      unless type == :all
        test_cmd << " -n '#{test_name}'" unless test_name.nil?
        system(test_cmd)
      end
      
    end
  end
  
  # allows you to quickly view your specs...
  def specs_for(type=nil,file=nil)
    msg = "specs_for is a hook that views your test/spec specs\n"
    msg << "==\n"
    msg << "specs_for [:unit,:func||:functional], :file"
    
    types_to_look_for = [:unit,:func,:functional]
    
    if ( !types_to_look_for.include?(type) || (type.nil? && file.nil?))
      puts msg
    else
      
      case type
      
        when :unit
          title = `cat test/unit/#{file.to_s}_test.rb | grep context`.split('"')[1]
          specs = [title,"==="]
          spec_string = `cat test/unit/#{file.to_s}_test.rb | grep 'specify'`.split("\n")
          spec_string.each do |spec|
            specs << spec.split('"')[1]
          end
          y specs
        
        when (:func || :functional)
          title = `cat test/functional/#{file.to_s}_controller_test.rb | grep context`.split('"')[1]
          specs = [title,"==="]
          spec_string = `cat test/functional/#{file.to_s}_controller_test.rb | grep 'specify'`.split("\n")
          spec_string.each do |spec|
            specs << spec.split('"')[1]
          end
          y specs
          
      end
      
    end
  end
  
  #hook for tail -f into the log dir...
  def trail(log=nil)
    if (log.nil? || ![:test,:production,:development].include?(log))
      puts "trail [:test|:production|:development]"
    else  
      system("tail -f log/#{log.to_s}.log")
    end  
  end
  
  # *** HELPERS ***
  #displays a list of javascripts
  def javascripts
    list = File.expand_path("public/javascripts")
    list_ary = Dir.entries(list).select{|x| x[0..0] != "."}
    list_ary.map!{|f| f.split(".")[0]}
    list_ary << ["===", "#{list_ary.length} Javascripts"]
    y list_ary.flatten!
  end

  #displays a list of all the stylesheets
  def stylesheets
    sheets = File.expand_path("public/stylesheets")
    sheets_ary = Dir.entries(sheets).select{|x| x[0..0] != "."}
    sheets_ary.map!{|f| f.split(".")[0]}
    footer = "#{sheets_ary.length} Stylesheets"
    sheets_ary << ["="*footer.length,footer ]
    y sheets_ary.flatten!
  end
  
  alias css stylesheets
  
  #displays a list of files for any directory
  def ls(dir=nil)
    return "USAGE : display [directory]" if dir.nil?
    files = File.expand_path dir.to_s
    files_ary = Dir.entries(files).select{|x| x[0..0] != "."}
    footer = "#{files_ary.length} Files"
    files_ary << ["="*footer.length,footer]
    y files_ary.flatten!
  end
  
  #displays the migrations in the app
  def migrations
    files = File.expand_path "db/migrate"
    files_ary = Dir.entries(files).select{|x| x[0..0] != "."}
    migrations = files_ary.map do |i| 
      migration = i.humanize.split(".").first
      if migration.split(" ").first.length == 14
        migration_ary = migration.split(" ")
        date, version = migration_ary.first.to_date, migration_ary.first
        migration_ary.delete migration_ary.first
        migrate_str = "[#{version}] : #{migration_ary.join(' ')} : #{date}"
        version == db_version(true) ? migrate_str << " [X]" : migrate_str
      else
        migration
      end
    end
    footer = "#{files_ary.length} Migrations"
    footer_border = "="*migrations.last.length
    migrations << [footer_border,footer]
    y migrations.flatten!
  end
  
  # display a list of all the plugins
  # pass in :name => plugin_name to view the README for that plugin
  def plugins(name=nil,opts=nil)
    if name.nil?
      list = File.expand_path("vendor/plugins")
      list_ary = Dir.entries(list).select{|x| x[0..0] != "."}
      footer = "="*list_ary.last.length
      list_ary << [footer, "#{list_ary.length} Plugins"]
      y list_ary.flatten!
    else
      # these are special cmds that you can pass instead of the name of the plugin
      cmds = %w(update help st)
      if cmds.include?(name.to_s.downcase)
        case name.to_s.downcase
          when "update"
            invalid_types = %w(. .. .DS_Store .svn)
            Dir.foreach("vendor/plugins") do |d|
              unless invalid_types.include?(d)
                # make sure we account for git and svn repos
                update_path = File.join("vendor/plugins",d)
                uses_git = File.exists?(File.join(update_path,".git"))
                uses_svn = File.exists?(File.join(update_path, ".svn"))
                not_versioned = !uses_git && !uses_svn
                
                update_path = File.join("vendor/plugins",d)
                puts "UPDATING : #{d}"
                # make sure we account for git and svn repos
                system("cd #{update_path};git pull") if uses_git
                svn.up(update_path) if uses_svn
                puts "#{d} not versioned" if not_versioned
              end
            end
          
          when "st"  
            invalid_types = %w(. .. .DS_Store)
            Dir.foreach("vendor/plugins") do |d|
              unless invalid_types.include?(d)
                # make sure we account for git and svn repos
                update_path = File.join("vendor/plugins",d)
                uses_git = File.exists?(File.join(update_path,".git"))
                uses_svn = File.exists?(File.join(update_path, ".svn"))
                not_versioned = !uses_git && !uses_svn
                
                repo_type = "[svn]" if uses_svn
                repo_type = "[git]" if uses_git
                repo_type = "[not versioned]" if not_versioned
                
                puts "STATUS OF : #{d} #{repo_type}"
                system("cd #{update_path};git st") if uses_git
                svn.st(update_path) if uses_svn
                puts "#{d} not versioned" if not_versioned
                puts "--"
              end
            end
          
          when "help"
            help = "plugins [name_of_plugin|cmd]\n"
            help << "==\n"
            help << "OPTIONS:\n"
            help << "- help : display this help file\n"
            help << "- update : update all plugins using svn:externals or git\n"
            help << "- st : gets the repo status of plugins\n"
            puts help
        end
        
      else
        if opts.nil?
          
          # support for different types of readmes
          readme_types = %w(README README.rdoc README.markdown README.textile README.txt)
          readme_ary = readme_types.map { |r| File.join("vendor/plugins/#{name}/", r) }
          cmd = nil
          readme_ary.each do |path|
            cmd = system("vi #{path}") if File.exists?(path)
          end
          cmd.nil? ? puts("README for #{name.to_s} doesn't exist...")  : cmd
          
        else
          
          # TODO write in support to include options to do the following:
          # 1. ci - git/svn checkin
          # 2. diff - git/svn diff
          # 3. spec/test - options to test plugins
            
        end

      end
    end    

  rescue Errno::ENOENT
    puts "Plugin : '#{name}' doesn't exist...try one below"
    plugins
  end
  
  #displays a list of all the models 
  #call with_attributes if you want to see all associated attributes 
  def models(with_attributes=nil)
    list = File.expand_path("app/models")
    list_ary = Dir.entries(list).select{|x| x[0..0] != "."}
    list_ary.map!{|f| f.split(".")[0].camelize}
    list_ary.map!{|l| [eval(l).schema] unless eval(l).nil?} unless with_attributes.nil?
    footer = "="*list_ary.last.length
    list_ary << [footer,"#{list_ary.length} Models"]
    y list_ary.flatten!
  end
  
  # displays all the mailer files
  def mailers
    list = Dir.glob File.join("app/models","*_mailer.rb")
    if list.length == 0
      return puts "There are no Mailers"
    else
      list.map!{ |mailer| mailer.split("/").last }
      list.map!{ |mailer| mailer.split(".").first }
      list.map!{ |mailer| mailer.camelize }
      list << [("="*list.last.length),"#{list.length} Mailers"]
      y list.flatten!
    end
  end

  #displays a list of controllers
  # pass in the controller option to open a controller file in vi
  def controllers(controller=nil)
    return vi("#{controller}_controller".to_sym) unless controller.nil?
    list = File.expand_path("app/controllers")
    list_ary = Dir.glob File.join(list, "*.rb")
    list_ary.map!{|f| f.split("/").last.split(".").first.camelize}
    summary = "#{list_ary.length} Controllers"
    list_ary << ["="*summary.length, summary]
    y list_ary.flatten!
  end
  
  # converts all rhtml files in app/view to html.erb
  def erb_convert
    files = `find app/views -name '*.rhtml'`
    file_ary = files.split("\n")
    file_ary.each do |file|
      new_file = file.gsub("rhtml", "html.erb") 
      FileUtils.mv file, new_file
    end
    puts "#{file_ary.length} files converted."
    puts "Don't forget to update your scm with the new files!"
  end

  
  # reads the methods for the file
  # you can pass a type of file to have it read a specific file
  # EX : 
  #     methods_for :users_controller # => app/controllers/users_controller.rb
  #     methods_for :user_model # => app/models/user.rb
  #     methods_for :users_helper # => app/helpers/users_helper.rb
  #     methods_for :users_functional # => test/functional/users_controller_test.rb
  #     methods_for :user_unit # => test/unit/user_test.rb
  #     methods_for :routes_config # => config/routes.rb
  #     methods_for 'my/special/file.rb' # => my/special/file.rb
  def methods_for(file=nil, return_ary=false)
    
    unless file.nil?
      types_to_look_for = ["controller",
                           "helper",
                           "model",
                           "unit",
                           "functional",
                           "config"]
                             
      name, type = file.to_s.split("_")
      path = types_to_look_for.include?(type) ? vi_file_path_for(type, name) : file
      parsed_file = IO.read(path)
      methods_ary = parsed_file.grep(/def/)
      methods_ary.map! {|action| action = action.split(" ")[1]}
      methods_ary.compact!
      methods_ary << ["===", "#{methods_ary.length} Methods for #{file}"]
      return_ary ? methods_ary : y(methods_ary.flatten!)
    else
      usage = "USAGE : methods_for [file(_controller|helper|model|unit|functional|config)]"
      puts usage
    end
  end
  
  #display views for a controller
  #pass return_ary to return the actions as an array
  def views_for(controller=nil, return_ary=false)
    unless controller.nil?
      list = File.expand_path("app/views/#{controller}")
      # we don't need the . entry or anything that might be considered a partial
      list_ary = Dir.entries(list).select{|x| ![".","_"].include? x[0..0] }
      list_ary.map! { |l| l.split(".")[0] }
      list_ary << ["===", "#{list_ary.length} Views for #{controller}"]
      return_ary ? list_ary : y(list_ary.flatten!)
    else
      puts "USAGE : views_for [name_of_controller]"  
    end
  end

  # generates a new view/rjs file for a controller
  def new_view_for(controller=nil,view=nil,type="html.erb")
    return "USAGE : new_view_for [controller] [name_of_view] [**file_type]" if controller.nil? || view.nil?
    view_path = "app/views/#{controller}/#{view}.#{type}"
    File.open(view_path,"w+")
    EDITORS.each do |editor|
      `#{editor} #{view_path}` if system("#{editor}")
      break if system("#{editor}")
    end

    return "View File : #{view}.#{type} has been created!"
  end
  
  #generates a new view folder
  def new_view_folder(name=nil)
    return "USAGE : new_view_folder [name]" if name.nil?
    dir_path = File.expand_path("app/views/#{name}")
    existing_dir = File.exists? dir_path
    Dir.mkdir("app/views/#{name}") unless existing_dir
    msg = existing_dir ? "Folder : #{name} already exists" : "Folder : #{name} has been created successfully!"
    return msg
  end
  
  # generates a new partial and opens in in textmate
  def new_partial_for(controller=nil,name=nil)
    return "USAGE : new_partial_for [controller] [name]" if (controller.nil? || name.nil?)
    controller, name = controller.to_s, name.to_s
    dir_path = File.expand_path("app/views/#{controller}")
    Dir.mkdir("app/views/#{controller}") unless File.exists? dir_path
    partial = File.join(dir_path,"_#{name}.html.erb")
    File.open(partial,"w+")
    system("mate #{partial}")
    return "Partial : #{partial} has been created!"
  end

  # generates a new layout for the app
  def new_layout_for(name=nil,type="html.erb")
    return "USAGE : new_layout_for [name_of_layout]" if name.nil?
    layout_path = "app/views/layouts/#{name}.#{type}"
    File.open(layout_path,"w+")
    # TM only function sorry win guys! ... maybe you can use e
    `mate #{layout_path}` if system("mate")
    `gedit #{layout_path}` if system("gedit")
    return "Layout File : #{name}.#{type} has been created!"
  end

  # generates a new js file for the app
  def new_js_for(name=nil)
    return "USAGE : new_js_for [name_of_js]" if name.nil?
    js_path = "public/javascripts/#{name}.js"
    File.open(js_path,"w+")
    # TM only function sorry win guys! ... maybe you can use e
    # system("mate #{js_path}")
    open_file_for js_path
    return "Javascript File : #{name}.js has been created!"
  end
  
  def new_rjs_for(controller=nil, name=nil, type="rjs")
    no_args = controller.nil? && name.nil?    
    return "USAGE : new_rjs_for [controller] [rjs_filename]" if no_args    
    return "You forgot the :name of the rjs file" if name.nil?
    return "You forgot the name of the controller" if controller.nil?
    
    rjs_path = "app/views/#{controller.to_s}/#{name.to_s}.#{type.to_s}"
    File.open(rjs_path,"w+")
    open_file_for rjs_path
    return "RJS File : #{name.to_s}.#{type.to_s} has been created!"
  end

  # generates a new css file for the app
  def new_css_for(name=nil)
    return "USAGE : new_css_for [name_of_css]" if name.nil?
    css_path = "public/stylesheets/#{name}.css"
    File.open(css_path,"w+")
    # TM only function sorry win guys! ... maybe you can use e
    system("mate #{css_path}")
    return "CSS File : #{name}.css has been created!"
  end
  
  # generates a spec yaml file
  def new_spec_for(type,name)
    usage = "USAGE : new_spec_for [:model|controller], [name_of_spec]" 
    return usage if type.nil? || ["model","controller"].include?(type.to_s)
    if type.to_s == "model"
      spec_path = "test/unit"
    elsif type.to_s == "controller"  
      spec_path = "test/functional"
    end
    spec_file_path = "#{spec_path}/#{name}_spec.yml"
    File.open(spec_file_path, "w+")
    system("mate #{spec_file_path}")
    return "Spec File : #{spec_file_path} has been created!"
  end

  #displays the number of layouts for the app
  def layouts
    files = Dir.glob("app/views/layouts/*.rhtml")
    files << Dir.glob("app/views/layouts/*.html.erb")
    files.flatten!.map! { |f| f.split("/").last.split(".").first }
    files << ["==","#{files.length} Layouts"]
    y files.flatten
  end

  #display partials for an action
  def partials_for(action=nil)
    unless action.nil?
      list = File.expand_path("app/views/#{action}")
      # we don't need the . entry or anything that might be considered a partial
      list_ary = Dir.entries(list).select{|x| ["_"].include? x.first }
      list_ary.map! { |l| l.split(".")[0].sub("_","")}
      footer = "#{list_ary.length} Partials for #{action}"
      list_ary << ["="*footer.length,footer ]
      y list_ary.flatten!
    else
      puts "USAGE : partials_for [name_of_action]"  
    end
  end
  
  
  # *** CONSOLE HOOKS ***
  # console hook into the ./script/generate command
  # EX : 
  #   generate :model, "User"
  #   generate :migration, "add avatar to user"
  #   generate :controller, "users index new add edit show destroy"
  def generate(type=nil, params=nil)
    if type.nil?
      return "USAGE : generate [:controller|:model|:migration|:plugin] [params]"
    else
      types = %w(controller model migration plugin mailer)
      # camelize the params, if we are generating a migration, this way we can
      # word migrations in plain english
      # EX : generate :migration, "add some special sauce to my model"
      params.gsub!(/[^a-z0-9]+/i, '_')  if type.to_sym == :migration
      return types.include?(type.to_s) ? system("./script/generate #{type.to_s} #{params}") : puts("#{type} is not a valid generator")
    end
  end

  # console hook for sake tasks
  # sake doesn't work right now 2007-09-21
  # def sake(task=nil)
  #   if task.nil?
  #     return "USAGE : sake [task name]"
  #   else
  #     return system("sake #{task}")  
  #   end  
  # end

  # console hook for ./script/destroy commands
  def destroy(type=nil, params=nil)
    if type.nil?
      return "USAGE : destroy [controller|model|migration] [params]"
    else
      types = %w(controller model migration)
      params.gsub!(/[^a-z0-9]+/i, '_') if type == :migration
      return types.include?(type.to_s) ? system("./script/destroy #{type.to_s} #{params}") : puts("#{type} is not a valid generator")
    end
  end

  # console hook for ./script/plugin commands
  def plugin(cmd=nil,params=nil)
    if cmd.nil?
      return "USAGE : plugin [install|list|discover|sources|source|remove|new|test]"
    else
      types = %w(install list discover sources source update remove new test)
      case cmd.to_sym
        
      when :install
        if params.split(".").last == "git"
          if File.exists?(".git")
            # make sure that add this as a submodule
            repo = params.split("/").last.split(".").first
            puts "Installing plugin : #{params} as a git submodule..."
            return system("git submodule add #{params} vendor/plugins/#{repo}")
          else
            # I prefer to clone git repositories...
            puts "Cloning plugin : #{params}"
            return system("cd vendor/plugins;git clone #{params}")            
          end
        else
          puts "Traditional install for plugin : #{params}"
          return system("./script/plugin #{cmd.to_s} #{params}")
        end
        
      when :new
        return generate(:plugin, params)
        
      when :test
        return puts("please supply a plugin to test") if params.nil?
        # you can pass the name of the plugin as the param or you can pass the full path
        # it assumes the the path of the plugin test is:
        #   vendor/plugins/[plugin_name]/test/[plugin_name]_test.rb
        if params.to_s.split("/").length == 1
          return system "ruby vendor/plugins/#{params.to_s}/test/#{params.to_s}_test.rb"
        elsif params.split("/").length > 1
          return system "ruby #{params}"
        end
      else
        if types.include?(cmd.to_s)
          return system("./script/plugin #{cmd.to_s} #{params}")
        else
          return puts("#{cmd} is not a valid plugin command")
        end
        
      end
      
    end  
  end
  
  # git hook
  def git(*args)
    if args.length == 1
      # EX : git :st 
      #      git "push origin master"
      cmd = "git #{args.first.to_s}"
    elsif args.length > 1
      # EX : git :st, :origin, :master
      #      git :push, :origin
      cmd = args.first.to_s
      args.delete_at(0)
      arg = args.join(" ")
      cmd = "git #{cmd} #{arg}"
    elsif args.blank?
      cmd = "git [*cmd] or git.[st|ci|push|config]"
    end
    
    cmd.instance_eval do
      
      # git.st
      def st
        system("git st")
      end
      
      # git.ci 'msg'
      def ci(msg=nil)
        cmd = msg.nil? ? "git add .;git commit" : "git add .;git commit -m '#{msg}'"
        system cmd
      end
      
      # git.push 'args' 
      def push(args=nil)
        args.nil? ? system("git push") : system("git push #{args}")
      end
      
      # git.url
      def url
        system 'cat .git/config | grep url'
      end
      
      # git.config
      def config
        system 'vi .git/config'
      end
      
      # git.ignore
      def ignore
        system 'vi .gitignore'
      end
      
      # git.modules
      def modules
        system 'less .gitmodules'
      end
      
      def show(rev=nil)
        rev.nil? ? system("git show") : system("git show #{rev}")
      end
      
      # git.log
      def log(path=nil)
        path.nil? ? system('git log') : system("git log #{path}")
      end
  
      # removes everything that has been removed from the filesystem
      def rm
        system "git st | grep deleted | sed -e 's/deleted: *//' | sed 's/# *//' | xargs git rm"
      end
      
      def diff
        system "git diff"
      end
      
    end
    
    args.blank? ? cmd : system(cmd)
  end
  
  # svn hook requires colordiff (http://colordiff.sourceforge.net/)
  # svn hook
  def svn(help=nil)
    @@repos = `svn info | grep URL`.split("URL:")[1].strip
    
    command = "USAGE : svn[.cmd] EXAMPLES : \n"
    command << "  svn.st [:plugin|dir]\n"
    command << "    - gets the status of the svn repos\n"
    command << "      options can be:\n"
    command << "        :plugin, :name_of_plugin # gets the status on a plugin\n"
    command << "        dir (a string value), EX: svn.st 'app/models/user.rb'\n"
    command << "  svn.ci [dir]\n"
    command << "    - checks in the changes, pass dir to \n"
    command << "      check in a specific directory \n"
    command << "  svn.add\n"
    command << "    - automatically adds all new files\n"
    command << "      to the repos\n"
    command << "  svn.info [dir]\n"
    command << "    - gets the info on the repos\n"
    command << "      you can optionally pass a dir\n"
    command << "      to get info on the dir"
    command << "  svn.ls options={}\n"
    command << "    - lists the files in the repos\n"
    command << "      options are:\n"
    command << "        :repos (defaults to internal.innerfusion.net)\n"
    command << "        :dir - the directory for which to query\n"
    command << "  svn.rm file\n"
    command << "    - removes a file from the repos\n"
    command << "  svn.up[dir]\n"
    command << "    - updates the repos\n"
    command << "      updates the current dir by default\n"
    command << "      pass in dir to update a specific dir\n"
    command << "  svn.log[limit]\n"
    command << "    - reviews the log of the most recent changes \n"
    command << "    - pass in limit to view the dif\n"
    command << "  svn.diff[:type|file]\n"
    command << "    - pass nothing to diff the whole app\n"
    command << "    - pass a symbol to diff a controller,model,js,or css file\n"
    command << "    - pass a string to diff a directory or a direct file"
    
    command.instance_eval do
      def rm(file=nil)
        file.nil? ? system('svn status | grep "^!" | sed -e "s/! *//" | sed -e "s/ / /g" | xargs svn rm;') : system("svn rm #{file}")
      end
      
      def up(dir=""); system("svn up #{dir}"); end
      
      # USAGE :
      # - svn.st # => svn st on the whole app
      # - svn.st :plugin, 'super_plugin' # => svn st on vendor/plugins/super_plugin
      # - svn.st 'my/cool/dir' # => svn st on my/cool/dir
      def st(type=nil,type_value=nil)
        if type == :plugin
          plugin_path = "vendor/plugins/#{type_value.to_s}"
          svn_exists = File.join plugin_path, ".svn"
          return svn_exists ? "svn st #{plugin_path}" : nil
        end
        return system("svn st #{type}") if type.is_a? String
        system("svn st | less")
      end
      
      # USAGE :
      # - svn.diff # => diffs the whole app
      # - svn.diff :model, :user # => diffs the user model 
      # - svn.diff 'my/cool/file.rb' # => diffs 'my/cool/file.rb'
      def diff(type=nil,type_value=nil)
        
        # FIXME : getting the following warning : svn: Can't write to stream: Broken pipe 
        case type.class
          when String
            return system("svn diff #{type} | colordiff | less -R")
          when Symbol
            # TODO :  finish the Symbol type of diffing
            return puts("TODO : nothing for symbols yet...") 
          else
            # uncomment to use vim instead
            # return system("svn diff | vim -R -")
            return system("svn diff | colordiff | less -R")
        end
        
      end
      
      #allows you to check in via svn.ci
      def ci(msg=nil)
        msg.nil? ? system("svn ci") : system("svn ci #{RAILS_ROOT} -m #{msg}")
      end
      
      # automatically add all new files into svn
      def add; system("svn status | grep '^?' | sed -e 's/? *//' | sed -e 's/ / /g' | xargs svn add"); end
      
      #allows you to get the info on anything
      def info(path=nil)
        path.nil? ? system("svn info") : system("svn info #{path.to_s}")
      end
      
      # reviews the log of the last 10 changes using less
      def log(limit=10)
        system("svn log #{@@repos} --limit #{limit} | less")
      end
      
    end
    return help.nil? ? command : puts(command)
  end
  
  # => capistrano hook deploy ... deploy your apps the ruby way
  def cap(help=nil)
    cap_cmd = "USAGE cap[.options] EXAMPLES: \n"
    cap_cmd << "   cap.deploy(args) = deploys using current version of capistrano \n"
    cap_cmd << "   cap.deploy_migrations(args) = deploys and migrates database\n"
    cap_cmd << "   cap.old_deploy =  deploys using capistrano 1.4.1\n"
    cap_cmd << "   cap.old_deploy_migrations =  deploys and migrates database (1.4.1)\n"
    cap_cmd << "   cap.tasks #=> shows all cap tasks\n"
    cap_cmd << "   cap.cleanup #=> cleans up the deployment revisions using current version of capistrano\n"
    cap_cmd << "   cap.old_cleanup #=> cleans up the deployment revisions using old version of capistrano\n"
    cap_cmd.instance_eval do
      
      def deploy(args=""); system("cap deploy #{args}"); end
      def deploy_migrations(args=""); system("cap deploy:migrations #{args}"); end
      def old_deploy; system("cap _1.4.1_ deploy"); end
      def old_deploy_migrations; system("cap _1.4.1_ deploy_with_migrations"); end
      def tasks; system("cap -T"); end
      def cleanup; system("cap deploy:cleanup"); end
      def old_cleanup; system("cap _1.4.1_ cleanup"); end
      
    end
    return help.nil? ? cap_cmd : puts(cap_cmd)
  end

  # => rake hooks for common tasks
  # console hook for rake
  def rake(cmd=nil)
    rake_cmd = "USAGE : rake[.cmd] \n"
    rake_cmd << "   rake.migrate [:up|:down|:reset|:redo] \n"
    rake_cmd << "    - migrates the database and clones it to the test env  \n"
    rake_cmd << "    - options for what kind of migration you want to do \n"
    rake_cmd << "       + :down => Migrates down \n"
    rake_cmd << "       + :up => Migrates up \n"
    rake_cmd << "       + :reset => Resets migrations \n"
    rake_cmd << "       + :redo => Migrates down one and back up \n"
    rake_cmd << "       + :rollback => Migrates down one \n"
    rake_cmd << "   rake.load_fixtures [:development|:test|:both] \n"
    rake_cmd << "     - loads the fixture defaults to development env \n"
    rake_cmd << "   rake.tasks \n"
    rake_cmd << "     - shows all the available rake tasks using less\n"
    rake_cmd << "   rake.call 'any available rake task'\n"
    rake_cmd << "     - calls any rake taks that you want to call"
    
    rake_cmd.instance_eval do
      def tasks; system("rake -T | less"); end
      
      def call(task)
        system("rake #{task}")
      end
      
      def routes
        less(`rake routes`)
      end
      # calls the migration tasks and then clones the test db... 
      # should be the default behavior if you ask me
      # hook into rake migrate
      def migrate(cmd=nil)
        cmd = cmd.nil? ? "rake db:migrate" : "rake:db:migrate:#{cmd.to_s}"
        system(cmd)
        system("rake db:test:clone")
      end
    
      def load_fixtures(env="both")
        available_envs = %w(test development both)
        notice_msg = "Only :test, :development, and :both are available as environments..."
        puts notice_msg unless available_envs.include?(env.to_s)
        env.to_s == "both" ? system("rake db:fixtures:load RAILS_ENV=development;rake db:fixtures:load RAILS_ENV=test") : system("rake db:fixtures:load RAILS_ENV=#{env}")
        puts "Fixtures for #{env} environment(s) has been loaded!"
      end
    end
    
    return cmd.nil? ? rake_cmd : system("rake #{cmd}")
      
  end

  # this is deprecated you can simple use the ar_helper#sugar methods instead
  # # alternative to Model#find :all
  # # it's nice and easy to read too, just type the following:
  # # all :users # => User.find(:all)
  # def all(model, options={})
  #   model_obj = eval model.to_s.singularize.camelize
  #   qry = model_obj.find(:all, options)
  # rescue NameError
  #   puts "The Model : #{model} doesn't exist... try again"
  # end
  # 
  # # alternative to Model#find :first
  # def first(model, options={})
  #   model_obj = eval model.to_s.singularize.camelize
  #   qry = model_obj.find(:first, options)
  #   rescue NameError
  #     puts "The Model : #{model} doesn't exist... try again"
  # end
  
end

class Symbol
  
  # extend symbol so you can make readable calls to fixture 
  # so you can do :users.fixtures 
  def fixture(fix_name=nil)
    return fix_name.nil? ? model.send(:fixture) : model.send(:fixture,fix_name.to_s)
  end
  
  def fixture_keys(fix_name=nil); model.send(:fixture_keys); end
  
  alias :f :fixture
  
  protected
    def model; self.to_s.singularize.camelize; end
end


class Object
  
  ## from : http://ozmm.org/posts/try.html
  #   @person ? @person.name : nil
  # vs
  #   @person.try(:name)
  def try(method)
    send method if respond_to? method
  end
  
  # TODO : find a way to init all fixtures to instance variables
  # def init_keys
  #   fixture_hash.keys.each do |fixture|
  #     # instance_variable_set(eval(":@#{fixture}"), f(fixture))
  #   end
  # end
  
  # TODO : create an extension of ActiveRecord's Migration methods so that
  # you can use it to as an extension to the model yourself
  # then you can do things like Model#add_column and such 
  # CleanSheet.to_s.pluralize.underscore.to_sym => :clean_sheets
  
  # since define_method is private, we will abstract it into a public method named create_method
  # so that we can just use Object#create_method when we want to dynamically create methods
  # Now you can do something like
  # ["one","two","three"].each { |n| Model.create_method("number_#{n}") { puts n }}
  # Now you have :
  #               Model.number_one # => one
  #               Model.number_two # => two
  #               Model.number_three # => three
  def create_method(name,&block)
    self.class.send(:define_method,name,&block)
  end
  
  # displays all local methods for the model
  def local_methods; y self.methods(false).sort; end
  
  # method searching to through instance and class methods
  def search_methods(string)
    search_results = ["--","CLASS METHODS","--"]
    search_results << self.methods.find_all{ |i| i.match(/#{string}/) }.sort 
    search_results << ["--", "INSTANCE METHODS","--"]
    search_results << self.instance_methods.find_all{ |i| i.match(/#{string}/) }.sort
    return y(search_results.flatten)
  end
  
  #Active Record Specific methods
  
  #display table schema information
  def schema(content=:standard)
    # y(compile_all_columns.flatten)
    output = compile_all_columns.join("\n")
    return content == :standard ? puts(output) : output
  end
  
  # displays all the fixtures with less
  def fixtures; system("ls test/fixtures | less"); end
  # TODO : build a cache method that will cache the results so we won't have to query the db everytime 
  #displays the fixtures for model being called
  # USAGE : Model#fixture # => displays the whole fixture
  #         Model#fixture "fixture_name" # => displays the specified fixture, returns nil if it doesn't exist
  #         Model#fixture(nil,true) # => pass true to the data param and it will return the value as a hash instead
  #         Model#fixture(:name_of_fixture,true)[:attribute] # => will return :attribute value in the hash
  def fixture(fixture_name=nil, data=false)
    f_name = "#{self.to_s.underscore.pluralize.downcase}.yml" 
    f_title = fixture_name.nil? ? f_name : "#{f_name} displaying #{fixture_name}"
    border = "=" * f_title.length
    ary = ["#{f_title}", border]
    # taken from rails' own fixtures.rb YAML::Omap::Fixtures#read_fixture_files
    yaml_string = ""
    yaml_file = "test/fixtures/#{f_name}"
    yaml_string << IO.read(yaml_file)
    # not all of our fixtures are using the new foxy_fixtures method and therefore we need to accomodate to both
    # types of fixtures
    fixtures = using_foxy_fixtures? ? YAML::load(erb_render(yaml_string)) : YAML::load(yaml_string)
    if fixtures == false
      # if the fixture file can't be read then the fixture file probably hasn't been filled in...
      data ? {} : puts("Looks like the #{self.to_s.downcase.pluralize} fixture file hasn't been filled in...")
    else
      # attach the id to each of the fixture hashes : this is dependent on foxy_fixtures
      fixtures.each_key { |f| fixtures[f].update("id" => Fixtures.identify(f.to_sym)) } if using_foxy_fixtures?

      # this is here for deprecation reasons... some old projects are still using fixture_references
      fix_hash = Hash.new
      relationships = nil
  
      fixtures.each do |key,val|
        if key.to_s =~ /fixtures/
          fix_hash[key.split("\n")[1]] = val
          relationships = key.split("\n")[0]
        else  
          fix_hash[key] = val
        end
      end
      fixtures = fix_hash
    
      load_fix = fixture_name.nil? ? fixtures.sort.map { |r| ["----\n#{r[0]}\n---"] << r[1..r.length] << ["---"] } : fixtures["#{fixture_name}"]
      ary << load_fix
      ary << ["====","LOADED FIXTURES","====",relationships] unless relationships.nil?
      data ? (fixture_name.nil? ? fixtures.symbolize_keys : fixtures["#{fixture_name}"].symbolize_keys) : y(ary.flatten)
    end
  end
  
  # shortcut for Model#fixture(:name_of_fixture,true)[:attribute] # => will return :attribute value in the hash
  def fixture_hash(fixture_name=nil)
    fixtures = fixture(fixture_name,true)
  end
  
  def fixture_keys
    ttl = "Fixture Keys for #{self}"
    border = "="*ttl.length
    keys = [ttl,border]
    keys << fixture_hash.keys
    keys << [border,"#{fixture_hash.keys.length} Keys"]
    keys = keys.flatten
    y keys
  end

  # returns the AR object so you get get associations and all that fun stuff with it
  # use like: User.f :jack # => #<User:0x3651fdc ... and all those other attrs
  # TODO : maybe add in a nil check for fixture_name
  def f(fixture_name)
    self.find(fixture_hash(fixture_name)[:id])
    
  rescue NoMethodError
    puts "Sorry that entry doesn't exist in the #{self.to_s.humanize} fixture, maybe try..."
    y fixture_hash.keys
  end
  
  # be careful this might conflict with Hash#keys
  alias :keys :fixture_keys
  
  protected
    def using_foxy_fixtures?
      # require 'test_help' if RAILS_GEM_VERSION.to_i >= 2
      if RAILS_GEM_VERSION.to_i >= 2
        require 'active_record'
        require 'active_record/fixtures'
      end
      Fixtures.respond_to?(:identify) 
    end
  
    def compile_all_columns
      columns = []
      ttl = "Schema for #{self}"
      ttl_border = "="*ttl.length
      cols = "- NAME : SQL TYPE : RUBY TYPE"
      cols_border = "="*cols.length
      columns << [ttl,ttl_border,cols,cols_border]
      self.columns.map do |c| 
        col = "- #{c.name} : #{c.sql_type} : #{c.type}"
        col << " [Default : #{c.default}]" unless c.default.nil?
        columns << col
      end
      num_of_cols = "#{self.columns.length} COLUMNS"
      columns << ["-"*num_of_cols.length, num_of_cols, "-"*num_of_cols.length]
      associations = self.reflect_on_all_associations
      # don't need to show associations if they doesn't exist
      unless associations.blank?
        associations.map { |a| columns << "- #{a.macro} :#{a.name} :class => #{a.class_name}"}
        num_of_associations = "#{associations.length} ASSOCIATIONS"
        noa_border = "-"*num_of_associations.length 
        columns << [noa_border,num_of_associations,noa_border]
      end  
      # add in validation_reflections if the validation_reflections plugin is available
      if self.respond_to? :reflect_on_all_validations
        validations = self.reflect_on_all_validations
        unless validations.blank?
          validations.map { |v| columns << "- #{v.macro} :#{v.name}" }
          num_of_validations = "#{validations.length} VALIDATIONS" 
          nov_border = "-"*num_of_validations.length
          columns << [nov_border,num_of_validations,nov_border]
        end  
      else
        columns << ["./script/plugin install validation_reflection if you want validation introspection"]  
      end  
      columns
    end
    
end if @script_console_running 

# generates a random date
# you can simply call it like random_date to generate a simple random date
# otherwise you can pass hash values to generate like
#       random_date :year => your_year, :month => range_of_month, 
#                   :day => range_of_days, :format => format_string (same as Date#strftime)
#                   :return_date => true/false (will return a date object if true)
def random_date(options={})
  options[:year] ||= Time.now.year
  options[:month] ||= rand(12)
  options[:day] ||= rand(31)
  options[:format] ||= "%Y-%m-%d"
  options[:return_date] ||= false

  str = "#{options[:year]}-#{options[:month]}-#{options[:day]}".to_date.strftime options[:format]
  date = "#{options[:year]}-#{options[:month]}-#{options[:day]}".to_date

  options[:return_date] ? date : str
# if the date is invalid let's re-try we'll probably get a valid date the next time around
# we're passing format because the format needs to stay consistent  
rescue ArgumentError
  random_date :format => options[:format]
end

# generates a random string
# thanks to snippet : http://snippets.dzone.com/posts/show/2111
def random_string(size=25)
  (1..size).collect { (i = Kernel.rand(62); i += ((i < 10) ? 48 : ((i < 36) ? 55 : 61 ))).chr }.join
end

def erb_render(fixture_content)
  ERB.new(fixture_content).result
end

def enable_trace( event_regex = /^(call|return)/, class_regex = /IRB|Wirble|RubyLex|RubyToken/ )
  puts "Enabling method tracing with event regex #{event_regex.inspect} and class exclusion regex #{class_regex.inspect}"

  set_trace_func Proc.new{|event, file, line, id, binding, classname|
    printf "[%8s] %30s %30s (%s:%-2d)\n", event, id, classname, file, line if
      event          =~ event_regex and
      classname.to_s !~ class_regex
  }
  return
end

def disable_trace
  puts "Disabling method tracing"

  set_trace_func nil
end
