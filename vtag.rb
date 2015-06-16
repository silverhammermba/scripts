#!/usr/bin/env ruby
# edit audio tags with vim

require 'taglib'
require 'tempfile'
require 'stringio'
require 'yaml'

# open a temp YAML file for editing, return edited contents
def edit_tmp_yaml
  Tempfile.open([$0, '.yaml']) do |temp|
    yield temp

    temp.flush

    system(ENV['EDITOR'] || 'vim', temp.path)

    temp.rewind

    return temp.read
  end
end

# convert seconds to H:M:S
def sec2hms sec
  h = sec / 3600
  m = (sec - h * 3600) / 60
  s = sec - h * 3600 - m * 60
  if h > 0
    "%d:%02d:%02d" % [h, m, s]
  elsif m > 0
    "%d:%02d" % [m, s]
  else
    "#{s} s"
  end
end

$write_keys = %w{album artist comment genre title track year}

# load file name and return hash of readonly properties
def readonly_hash_from_file name
  TagLib::FileRef.open(name) do |f|
    if f.null?
      raise Errno::ENOENT, "No such file or directory - #{name}"
    end

    props = f.audio_properties
    return {
      'bitrate' => "#{props.bitrate} kb/s",
      'channels' => props.channels,
      'length' => "#{sec2hms props.length}",
      'sample rate' => "#{props.sample_rate} Hz"
    }
  end
end

# load file name, return hash with tag information
def tag_hash_from_file name
  TagLib::FileRef.open(name) do |f|
    if f.null?
      raise Errno::ENOENT, "No such file or directory - #{name}"
    end

    return $write_keys.map { |key| [key, f.tag.send(key)] }.to_h
  end
end

# edit tag fields in file name using hash
def tag_hash_to_file tags, name
  TagLib::FileRef.open(name) do |f|
    if f.null?
      raise Errno::ENOENT, "No such file or directory - #{name}"
    end

    return if tags.empty?

    tags.each do |key, value|
      # don't write empty strings, just clear the field
      value = nil if value.is_a?(String) && value.empty?

      begin
        f.tag.send("#{key}=", value)
      rescue TypeError
        value = Integer(value, 10)
        retry
      end
    end

    f.save
  end
end

# load file with name, return string with tag information
def tag_str_from_file name
  readonly = readonly_hash_from_file name
  writeable = tag_hash_from_file name

  str = StringIO.new

  str.puts "# #{name}"
  str.puts "#"
  readonly.each { |k, v| str.puts "# #{k}: #{v}" }
  str.puts YAML.dump(writeable)

  str.string
end

# parse tag hash from string
def tag_hash_from_str str
  YAML.load(str)
end

# parse tag hash from str, save to tags in file name
def tag_str_to_file str, name
  tag_hash_to_file tag_hash_from_str(str), name
end

# option for editing multiple files
if ARGV.delete('--common')
  hashes = ARGV.map { |name| tag_hash_from_file(name).to_h }

  # find which tag fields are common among the files
  keys = hashes.flat_map { |hash| hash.keys }.uniq
  common = keys.select { |key| hashes.map { |hash| hash[key] }.uniq.compact.size <= 1 }
  leftover = $write_keys - common

  str = edit_tmp_yaml do |temp|
    # print common tags
    ck = common.map do |key|
      [key, hashes.map { |hash| hash[key] }.uniq.compact[0]]
    end.to_h
    temp.puts YAML.dump(ck)

    # print other tag in comments
    leftover.each do |key|
      temp.puts "# #{key}:"
    end
    temp.puts

    ARGV.each do |name|
      temp.puts "# #{name}"
    end
  end

  # save changes
  ARGV.each do |name|
    tag_hash_to_file tag_hash_from_str(str), name
  end

  exit
end

ARGV.each do |name|
  str = tag_str_from_file(name)
  new_str = edit_tmp_yaml { |temp| temp.write str }

  # TODO more robust check for changes?
  if str == new_str
    next
  end

  tag_str_to_file new_str, name
end
