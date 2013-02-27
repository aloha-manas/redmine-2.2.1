desc 'Updates and checks locales against en.yml'
task :locales do
  %w(locales:update locales:check_interpolation).collect do |task|
    Rake::Task[task].invoke
  end
end

namespace :locales do
  desc 'Updates language files based on en.yml content (only works for new top level keys).'
  task :update do
    dir = ENV['DIR'] || './config/locales'

    en_strings = YAML.load(File.read(File.join(dir,'en.yml')))['en']

    files = Dir.glob(File.join(dir,'*.{yaml,yml}'))
    files.sort.each do |file|
      puts "Updating file #{file}"
      file_strings = YAML.load(File.read(file))
      file_strings = file_strings[file_strings.keys.first]

      missing_keys = en_strings.keys - file_strings.keys
      next if missing_keys.empty?

      puts "==> Missing #{missing_keys.size} keys (#{missing_keys.join(', ')})"
      lang = File.open(file, 'a')

      missing_keys.each do |key|
        {key => en_strings[key]}.to_yaml.each_line do |line|
          next if line =~ /^---/ || line.empty?
          puts "  #{line}"
          lang << "  #{line}"
        end
      end

      lang.close
    end
  end

  desc 'Checks interpolation arguments in locals against en.yml'
  task :check_interpolation do
    dir = ENV['DIR'] || './config/locales'
    en_strings = YAML.load(File.read(File.join(dir,'en.yml')))['en']
    files = Dir.glob(File.join(dir,'*.{yaml,yml}'))
    files.sort.each do |file|
      puts "parsing #{file}..."
      file_strings = YAML.load(File.read(file))
      file_strings = file_strings[file_strings.keys.first]

      file_strings.each do |key, string|
        next unless string.is_a?(String)
        string.scan /%\{\w+\}/ do |match|
          unless en_strings[key].nil? || en_strings[key].include?(match)
            puts "#{file}: #{key} uses #{match} not found in en.yml"
          end
        end
      end
    end
  end

  desc <<-END_DESC
Removes a translation string from all locale file (only works for top-level childless non-multiline keys, probably doesn\'t work on windows).

This task does not work on Ruby 1.8.6.
You need to use Ruby 1.8.7 or later.

Options:
  key=key_1,key_2    Comma-separated list of keys to delete
  skip=en,de         Comma-separated list of locale files to ignore (filename without extension)
END_DESC

  task :remove_key do
    dir = ENV['DIR'] || './config/locales'
    files = Dir.glob(File.join(dir,'*.yml'))
    skips = ENV['skip'] ? Regexp.union(ENV['skip'].split(',')) : nil
    deletes = ENV['key'] ? Regexp.union(ENV['key'].split(',')) : nil
    # Ignore multiline keys (begin with | or >) and keys with children (nothing meaningful after :)
    delete_regex = /\A  #{deletes}: +[^\|>\s#].*\z/

    files.each do |path|
      # Skip certain locales
      (puts "Skipping #{path}"; next) if File.basename(path, ".yml") =~ skips
      puts "Deleting selected keys from #{path}"
      orig_content = File.open(path, 'r') {|file| file.read}
      File.open(path, 'w') {|file| orig_content.each_line {|line| file.puts line unless line.chomp =~ delete_regex}}
    end
  end

  desc <<-END_DESC
Adds a new top-level translation string to all locale file (only works for childless keys, probably doesn\'t work on windows, doesn't check for duplicates).

Options:
  key="some_key=foo"
  key1="another_key=bar"
  key_fb="foo=bar"         Keys to add in the form key=value, every option of the form key[,\\d,_*] will be recognised
  skip=en,de               Comma-separated list of locale files to ignore (filename without extension)
END_DESC

  task :add_key do
    dir = ENV['DIR'] || './config/locales'
    files = Dir.glob(File.join(dir,'*.yml'))
    skips = ENV['skip'] ? Regexp.union(ENV['skip'].split(',')) : nil
    keys_regex = /\Akey(\d+|_.+)?\z/
    adds = ENV.reject {|k,v| !(k =~ keys_regex)}.values.collect {|v| Array.new v.split("=",2)}
    key_list = adds.collect {|v| v[0]}.join(", ")

    files.each do |path|
      # Skip certain locales
      (puts "Skipping #{path}"; next) if File.basename(path, ".yml") =~ skips
      # TODO: Check for dupliate/existing keys
      puts "Adding #{key_list} to #{path}"
      File.open(path, 'a') do |file|
        adds.each do |kv|
          Hash[*kv].to_yaml.each_line do |line|
            file.puts "  #{line}" unless (line =~ /^---/ || line.empty?)
          end
        end
      end
    end
  end

  desc 'Duplicates a key. Exemple rake locales:dup key=foo new_key=bar'
  task :dup do
    dir = ENV['DIR'] || './config/locales'
    files = Dir.glob(File.join(dir,'*.yml'))
    skips = ENV['skip'] ? Regexp.union(ENV['skip'].split(',')) : nil
    key = ENV['key']
    new_key = ENV['new_key']
    abort "Missing key argument" if key.blank?
    abort "Missing new_key argument" if new_key.blank?

    files.each do |path|
      # Skip certain locales
      (puts "Skipping #{path}"; next) if File.basename(path, ".yml") =~ skips
      puts "Adding #{new_key} to #{path}"

      strings = File.read(path)
      unless strings =~ /^(  #{key}: .+)$/
        puts "Key not found in #{path}"
        next
      end
      line = $1

      File.open(path, 'a') do |file|
        file.puts(line.sub(key, new_key))
      end
    end
  end

  desc 'Check parsing yaml by psych library on Ruby 1.9.'

  # On Fedora 12 and 13, if libyaml-devel is available,
  # in case of installing by rvm,
  # Ruby 1.9 default yaml library is psych.

  task :check_parsing_by_psych do
    begin
      require 'psych'
      parser = Psych::Parser.new
      dir = ENV['DIR'] || './config/locales'
      files = Dir.glob(File.join(dir,'*.yml'))
      files.sort.each do |filename|
        next if File.directory? filename
        puts "parsing #{filename}..."
        begin
          parser.parse File.open(filename)
        rescue Exception => e1
          puts(e1.message)
          puts("")
        end
      end
    rescue Exception => e
      puts(e.message)
    end
  end
end
