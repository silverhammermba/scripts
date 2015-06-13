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

# load file with name, return string with tag information
def tag_str_from_file name
  readonly = nil
  writeable = nil

  TagLib::FileRef.open(name) do |f|
    if f.null?
      raise Errno::ENOENT, "No such file or directory - #{name}"
    end

    props = f.audio_properties
    readonly = {
      'bitrate' => "#{props.bitrate} kb/s",
      'channels' => props.channels,
      'length' => "#{sec2hms props.length}",
      'sample rate' => "#{props.sample_rate} Hz"
    }

    write_keys = %w{album artist comment genre title track year}
    writeable = write_keys.map { |key| [key, f.tag.send(key)] }.to_h
  end

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

# parse tag information from str, save to tags in file name
def tag_str_to_file str, name
  kv = str.lines.select { |line| line =~ /^\s*[^#].*:/ }.map { |line| line.split(?:, 2).map(&:strip) }

  TagLib::FileRef.open(name) do |f|
    if f.null?
      raise Errno::ENOENT, "No such file or directory - #{name}"
    end

    kv.each do |key, value|
      value = nil if value.empty?
      begin
        f.tag.send("#{key}=", value)
      rescue TypeError
        if value.is_a?(String) && value =~ /^\d+$/
          value = value.to_i
          retry
        else
          raise
        end
      end
    end

    f.save
  end
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
