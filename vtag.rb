#!/usr/bin/env ruby
# edit audio tags with vim

require 'optparse'
require 'stringio'
require 'taglib'
require 'tempfile'
require 'yaml'

class Integer
  # convert seconds to H:M:S
  def to_hms
    h = self / 3600
    m = (self - h * 3600) / 60
    s = self - h * 3600 - m * 60
    if h > 0
      "%d:%02d:%02d" % [h, m, s]
    elsif m > 0
      "%d:%02d" % [m, s]
    else
      "#{s} s"
    end
  end
end

# wrapper around TagLib::FileRef
class AudioFile
  WRITE_KEYS = %w{album artist comment genre title track year}

  attr_reader :name

  def initialize name
    @name = name
  end

  # get readonly properties
  def readonly_props
    open do |f|
      props = f.audio_properties
      {
        'bitrate' => "#{props.bitrate} kb/s",
        'channels' => props.channels,
        'length' => "#{props.length.to_hms}",
        'sample rate' => "#{props.sample_rate} Hz"
      }
    end
  end

  # get editable tag fields
  def props
    open do |f|
      WRITE_KEYS.map { |key| [key, f.tag.send(key)] }.to_h
    end
  end

  # set tag fields
  def props= tags
    return if tags.empty?

    open do |f|
      tags.each do |key, value|
        # don't write empty strings, just clear the field
        value = nil if value.is_a?(String) && value.empty?

        begin
          f.tag.send("#{key}=", value)
        rescue NoMethodError
          raise "Invalid tag frame - #{key}"
        rescue TypeError
          # try converting to int if edit failed
          value = Integer(value, 10)
          retry
        end
      end

      f.save
    end
  end

  private

  def open
    TagLib::FileRef.open(@name) do |f|
      raise "Not an audio file - #@name" if f.null?
      return yield(f)
    end
  end
end

# open temp YAML file(s) for editing, return edited contents
def edit_tmp_yaml num = nil
  name = File.basename($0, File.extname($0))
  temps = Array.new(num || 1) { Tempfile.new([name, '.yaml']) }

  if num
    yield temps
  else
    yield temps[0]
  end

  temps.each(&:flush)
  system(ENV['EDITOR'] || 'vim', *temps.map(&:path))
  temps.each(&:rewind)

  if num
    return temps.map(&:read)
  else
    return temps[0].read
  end
ensure
  temps.each(&:close)
end

### MAIN PROCEDURES ###

# edit one tag for all files
def edit_all files
  hashes = files.map(&:props)

  # find which tag fields are common among the files
  keys = hashes.flat_map { |hash| hash.keys }.uniq
  common = keys.select { |key| hashes.map { |hash| hash[key] }.uniq.compact.size <= 1 }
  leftover = AudioFile::WRITE_KEYS - common

  new_str = edit_tmp_yaml do |temp|
    # print common tags
    ck = common.map do |key|
      [key, hashes.map { |hash| hash[key] }.uniq.compact[0]]
    end.to_h
    temp.puts YAML.dump(ck)

    # print other tags in comments
    leftover.each do |key|
      temp.puts "##{key}:"
    end
    temp.puts

    files.each do |file|
      temp.puts "# #{file.name}"
    end
  end

  # save changes
  props = YAML.load(new_str)
  files.each do |file|
    file.props = props
  end
end

# edit each file's tag
def edit_multiple files
  strs = files.map do |file|
    str = StringIO.new

    str.puts "# #{file.name}"
    str.puts "#"
    file.readonly_props.each { |k, v| str.puts "# #{k}: #{v}" }
    str.puts YAML.dump(file.props)

    str.string
  end

  new_strs = edit_tmp_yaml(files.size) do |tmps|
    strs.zip(tmps).each { |str, tmp| tmp.write str }
  end

  files.zip(strs, new_strs).each do |file, str, new_str|
    # TODO more robust check for changes?
    if str == new_str
      next
    end
    file.props = YAML.load(new_str)
  end
end

# default behavior
op = :edit_multiple

options = OptionParser.new do |opts|
  opts.banner = "Usage: #$0 [--all] [FILES]"

  opts.on('-a', '--all', 'Edit all file tags at once') do
    op = :edit_all
  end
end

options.parse!

if ARGV.empty?
  warn options
  exit 1
end

send(op, ARGV.map { |name| AudioFile.new(name) })
