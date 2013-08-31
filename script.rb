class FormatChecker
  ALLOWED_EXTENSIONS = %w(.yml .slim .haml)

  def initialize
    @changes = false
    @count = 0

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
              input
            end

    if ALLOWED_EXTENSIONS.include?(File.extname(input)) && File.exists?(input)
      perform_in_file(input)
    elsif File.directory?(input)
      perform_in_dir(input)
    else
      puts "File or folder not specified or doesn't fit extension requirements."
    end

    puts "Problems: #{@count}"
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

  def perform_in_file(file)
    file = File.open(file, 'r')

    file.each_line.with_index do |string, index|
      string.force_encoding "utf-8"
      unless string.valid_encoding?
        @count = @count + 1
        puts "\033[31mLine: #{index + 1}. Problem - #{string.strip}\033[0m"
        # puts "\033[31m#{string.dec_to_utf8}\033[0m"
        puts "\033[34m#{string.latin1_to_utf8}\033[0m"
        puts "\033[34m#{string.cp1252_to_utf8}\033[0m"
        # puts "\033[31m#{string.utf16le_to_utf8}\033[0m"
      end
    end
  end

  def valid

  end
end

class Formatter
  def initialize

  end
end

class String
  require 'iconv'

  # taken from: http://www.w3.org/International/questions/qa-forms-utf-8
  UTF8REGEX = /\A(?:[\x09\x0A\x0D\x20-\x7E] | [\xC2-\xDF][\x80-\xBF] | \xE0[\xA0-\xBF][\x80-\xBF] | [\xE1-\xEC\xEE\xEF][\x80-\xBF]{2} | \xED[\x80-\x9F][\x80-\xBF] | \xF0[\x90-\xBF][\x80-\xBF]{2} | [\xF1-\xF3][\x80-\xBF]{3} | \xF4[\x80-\x8F][\x80-\xBF]{2})*\z/mnx

  def utf8?
    self.force_encoding('ASCII-8BIT') =~ UTF8REGEX
  end

  def clean_utf8
      t = ""
      self.scan(/./um) { |c| t << c if c =~ UTF8REGEX }
      t
  end

  # cf. Paul Battley, http://po-ru.com/diary/fixing-invalid-utf-8-in-ruby-revisited/
  def validate_utf8
     Iconv.iconv('UTF-8//IGNORE', 'UTF-8', (self + ' ') ).first[0..-2]
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
