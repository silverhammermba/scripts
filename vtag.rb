#!/usr/bin/env ruby
# edit audio tags with vim

require 'optparse'
require 'stringio'
require 'taglib'
require 'tempfile'
require 'yaml'

# open temp YAML file(s) for editing, return edited contents
def edit_tmp_yaml num = nil
  temps = Array.new(num || 1) { Tempfile.new([$0, '.yaml']) }

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

# edit one tag file for all args
def edit_all names
  hashes = names.map { |name| tag_hash_from_file(name).to_h }

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

    # print other tags in comments
    leftover.each do |key|
      temp.puts "##{key}:"
    end
    temp.puts

    names.each do |name|
      temp.puts "# #{name}"
    end
  end

  # save changes
  names.each do |name|
    tag_hash_to_file tag_hash_from_str(str), name
  end
end

# edit tag file for each arg
def edit_multiple names
  strs = names.map { |name| tag_str_from_file name }
  new_strs = edit_tmp_yaml(names.size) do |tmps|
    strs.zip(tmps).each { |str, tmp| tmp.write str }
  end

  names.zip(strs, new_strs).each do |name, str, new_str|
    # TODO more robust check for changes?
    if str == new_str
      next
    end
    tag_str_to_file new_str, name
  end
end

op = :edit_multiple
OptionParser.new do |opts|
  opts.banner = "Usage: #$0 [--all] [FILES]"

  opts.on('-a', '--all', 'Edit all file tags at once') do
    op = :edit_all
  end
end.parse!

send op, ARGV
