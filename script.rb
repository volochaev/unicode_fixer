require 'pry'
require 'yaml'

class FormatChecker
  ALLOWED_EXTENSIONS = %w(.yml .slim .haml)

  def initialize
    @changes = false
    @total_count = 0
    @default_encoding = nil

    puts "Enter filename or path to folder, allowed extensions is: #{ALLOWED_EXTENSIONS.join(', ')}."
    puts "Current path is #{Dir.pwd}"
    input = $stdin.gets.chomp

    input = case input
            when "exit", "quit", "q"
              return
            when nil || ""
              puts "\033[31mWARNING: Using current directory. Are you sure? [y/n]\033[0m"
              $stdin.gets.chomp == 'y' ? Dir.pwd : return
            else
              input.strip
            end

    if ALLOWED_EXTENSIONS.include?(File.extname(input)) && File.exists?(input)
      perform_in_file(input)
    elsif File.directory?(input)
      perform_in_dir(input)
    else
      puts "File or folder not specified or doesn't fit extension requirements."
    end

    puts "Problems: #{@total_count}"
  end

  private

  def perform_in_dir(directory)
    working_dir = Dir.open directory

    working_dir.each do |file|
      if ALLOWED_EXTENSIONS.include? File.extname(file)
        puts "\033[32mOpen #{file}\033[0m"
        perform_in_file([working_dir.path, '/', file].join)
      else
        puts "\033[34m#{file} extension is wrong. skipping.\033[0m"
      end
    end
  end

  def perform_in_file(input_file)
    file, errors_count, lines = File.open(input_file, 'r'), 0, []


    if File.extname(input_file) == '.yml'
      yml_valid = yaml_valid?(input_file)
      puts "\033[33mChecking YAML structure. Valid: #{yml_valid}\033[0m"
    end

    file.each_line.with_index do |string, index|
      string.force_encoding "utf-8"
      unless string.valid_encoding?
        errors_count += 1
        lines << index + 1
      end
    end

    file.close

    if errors_count >= 1
      puts "\033[31m#{errors_count} errors was found.\033[0m"
      puts "Lines: #{lines.join(', ')}" if lines.any?
      puts "Fix errors? [y/n]"

      case $stdin.gets.chomp
      when 'y'
        puts "Saving backup"
        file = File.open(input_file, 'r')
        FileUtils.mv(file.path, file.path << '_backup')

        tempfile = File.open("#{input_file}_new", 'w+')

        file.each_line do |line|
          if line.valid_encoding?
            tempfile << line
          else
            tempfile << encode(line)
          end
        end

        file.close
        File.rename("#{input_file}_new", input_file)
        tempfile.close
      end
      @total_count += errors_count
    end
  end

  def encode(line)
    unless @default_encoding
      puts "\033[35mUnmodified: #{line.strip}\033[0m"
      puts "\033[33mChoose encoding: [1/2/default 1/default 2]\033[0m"
      puts "[1 @ ISO-8859-1] #{line.latin1_to_utf8.strip}"
      puts "[2 @ CP1252] #{line.cp1252_to_utf8.strip}"
      puts "\033[33mIf you choose any of the `default *` options it will be automatically applied for next errors. Use with caution.\033[0m"
      puts "[default 1] Set default encoding as ISO-8859-1"
      puts "[default 2] Set default encoding as CP1252"
    end

    format line
  end

  def format(line)
    output =  case @default_encoding || $stdin.gets.chomp
              when '1' then line.latin1_to_utf8
              when '2' then line.cp1252_to_utf8
              when /\Adefault\s(\d)\z/i then @default_encoding = $1 and format(line)
              end
    output.force_encoding "utf-8"
  end

  def yaml_valid?(file)
    !!YAML.load_file(file)
  end
end

class String
  require 'iconv'
  # original: http://dzone.com/snippets/utf8-aware-string-methods-ruby

  # taken from: http://www.w3.org/International/questions/qa-forms-utf-8
  UTF8REGEX = /\A(?:[\x09\x0A\x0D\x20-\x7E] | [\xC2-\xDF][\x80-\xBF] | \xE0[\xA0-\xBF][\x80-\xBF] | [\xE1-\xEC\xEE\xEF][\x80-\xBF]{2} | \xED[\x80-\x9F][\x80-\xBF] | \xF0[\x90-\xBF][\x80-\xBF]{2} | [\xF1-\xF3][\x80-\xBF]{3} | \xF4[\x80-\x8F][\x80-\xBF]{2})*\z/mnx

  def utf8?
    self.force_encoding('ASCII-8BIT') =~ UTF8REGEX
  end

  def latin1_to_utf8 # ISO-8859-1 to UTF-8
     ret = Iconv.iconv("UTF-8//IGNORE", "ISO-8859-1", (self + "\x20") ).first[0..-2]
     ret.utf8? ? ret : nil
  end

  def cp1252_to_utf8 # CP1252 (WINDOWS-1252) to UTF-8
     ret = Iconv.iconv("UTF-8//IGNORE", "CP1252", (self + "\x20") ).first[0..-2]
     ret.utf8? ? ret : nil
  end
end

FormatChecker.new
