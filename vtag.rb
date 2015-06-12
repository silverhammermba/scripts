#!/usr/bin/env ruby
# edit audio tags with vim

require 'taglib'
require 'tempfile'

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

write_keys = %w{album artist comment genre title track year}

ARGV.each do |name|
  TagLib::FileRef.open(name) do |f|
    if f.null?
      warn "Can't load #{f}"
      next
    end

    props = f.audio_properties
    readonly = {
      'bitrate' => "#{props.bitrate} kb/s",
      'channels' => props.channels,
      'length' => "#{sec2hms props.length}",
      'sample rate' => "#{props.sample_rate} Hz"
    }

    writeable = write_keys.map { |key| [key, f.tag.send(key)] }.to_h

    data = nil

    Tempfile.open(name) do |t|
      t.puts "# #{name}"
      t.puts "#"
      mk = readonly.keys.map(&:length).max
      readonly.each do |k, v|
        t.puts "# %#{mk}s: #{v}" % k
      end
      t.puts

      mk = writeable.keys.map(&:length).max
      writeable.each do |k, v|
        t.puts "%#{mk}s: #{v}" % k
      end

      t.puts
      t.puts "# vi:syntax=yaml"
      t.flush

      system("vim", t.path)

      t.rewind

      data = t.read
    end
  end
end
