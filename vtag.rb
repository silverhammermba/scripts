#!/usr/bin/env ruby
# edit audio tags with vim

require 'taglib'
require 'tempfile'
require 'stringio'

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
def readonly_from_file name
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

# load file with name, return hash with tag information
def kv_from_file name
  TagLib::FileRef.open(name) do |f|
    if f.null?
      raise Errno::ENOENT, "No such file or directory - #{name}"
    end

    return $write_keys.map { |key| [key, f.tag.send(key)] }.to_h
  end
end

# edit tag fields in file name using hash
def kv_to_file hash, name
  TagLib::FileRef.open(name) do |f|
    if f.null?
      raise Errno::ENOENT, "No such file or directory - #{name}"
    end

    return if hash.empty?

    hash.each do |key, value|
      # don't write empty strings, just clear the field
      value = nil if value.is_a?(String) && value.empty?

      begin
        f.tag.send("#{key}=", value)
      rescue TypeError
        # try converting numeral strings to integers
        if value.is_a?(String) && value =~ /^\d+$/
          value = value.to_i
          retry
        end

        raise
      end
    end

    f.save
  end
end

# load file with name, return string with tag information
def tag_str_from_file name
  readonly = readonly_from_file name
  writeable = kv_from_file name

  str = StringIO.new

  str.puts "# #{name}"
  str.puts "#"
  key_length = readonly.keys.map(&:length).max
  readonly.each do |k, v|
    str.puts "# %#{key_length}s: #{v}" % k
  end
  str.puts

  key_length = writeable.keys.map(&:length).max
  writeable.each do |k, v|
    str.puts "%#{key_length}s: #{v}" % k
  end

  str.string
end

# convert YAML to a Hash (very naively)
def kv_from_str str
  str.lines.select { |line| line =~ /^\s*[^#].*:/ }.map { |line| line.split(?:, 2).map(&:strip) }
end

# parse tag information from str, save to tags in file name
def tag_str_to_file str, name
  kv = kv_from_str str

  kv_to_file kv, name
end

if ARGV.delete('--common')
  hashes = ARGV.map { |name| kv_from_file(name).to_h }

  # find which tag fields are common among the files
  keys = hashes.flat_map { |hash| hash.keys }.uniq
  common = keys.select { |key| hashes.map { |hash| hash[key] }.uniq.compact.size <= 1 }
  leftover = $write_keys - common

  kv = nil

  # output common keys for editing
  Tempfile.open([$0, '.yaml']) do |temp|
    key_length = $write_keys.map(&:length).max

    common.each do |key|
      value = hashes.map { |hash| hash[key] }.uniq.compact[0]
      temp.puts "  %#{key_length}s: #{value}" % key
    end
    leftover.each do |key|
      temp.puts "# %#{key_length}s:" % key
    end
    temp.puts

    ARGV.each do |name|
      temp.puts "# #{name}"
    end

    temp.flush

    system(ENV['EDITOR'] || "vim", temp.path)

    temp.rewind
    kv = kv_from_str temp.read
  end

  # save changes
  ARGV.each do |name|
    kv_to_file kv, name
  end

  exit
end

ARGV.each do |name|
  str = tag_str_from_file(name)
  new_str = nil

  Tempfile.open([$0, '.yaml']) do |temp|
    temp.write str
    temp.flush

    system(ENV['EDITOR'] || "vim", temp.path)

    temp.rewind
    new_str = temp.read
  end

  # TODO more robust check for changes?
  if str == new_str
    next
  end

  tag_str_to_file new_str, name
end
