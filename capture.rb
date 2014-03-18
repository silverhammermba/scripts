#!/usr/bin/env ruby
# screen capture

require 'optparse'

$audio = ''
$capture = ''

OptionParser.new do |opts|
  opts.banner = "Usage #$0 [OPTIONS]"
  opts.on('-m', '--mic', 'Record mic input') do |v|
    $audio = '-f alsa -i default'
  end
  opts.on('-r', '--root', 'Capture root window') do |v|
    $capture = '-root'
  end
end.parse!

# get window dimensions
win_info = `xwininfo #$capture`
x = win_info[/Absolute upper-left X:\s+(\d+)/, 1].to_i
y = win_info[/Absolute upper-left Y:\s+(\d+)/, 1].to_i
w = win_info[/Width:\s+(\d+)/, 1].to_i
h = win_info[/Height:\s+(\d+)/, 1].to_i

$res = "#{w}x#{h}"

$filename = Time.new.strftime("%F-%H%M%S") + "_#{$res}_ffmpeg.mkv"

exec "ffmpeg -video_size #$res -f x11grab -i :0.0+#{x},#{y} #$audio -c:v ffvhuff -c:a flac #$filename"
