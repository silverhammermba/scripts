#!/usr/bin/env ruby
# record video of screen

$audio = ''
$capture = ''

if ARGV.delete('-a') or ARGV.delete('--alsa')
  $audio = '-f alsa -i default'
end

if ARGV.delete('-r') or ARGV.delete('--root')
  $capture = '-root'
end

# get window dimensions
win_info = `xwininfo #$capture`
x = win_info[/Absolute upper-left X:\s+(\d+)/, 1].to_i
y = win_info[/Absolute upper-left Y:\s+(\d+)/, 1].to_i
w = win_info[/Width:\s+(\d+)/, 1].to_i
h = win_info[/Height:\s+(\d+)/, 1].to_i

$res = "#{w}x#{h}"

$filename = Time.new.strftime("%F-%H%M%S") + "_#{$res}_ffmpeg.mkv"

exec "ffmpeg -video_size #$res -f x11grab -i :0.0+#{x},#{y} #$audio -c:v ffvhuff -c:a flac #$filename"
