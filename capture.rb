#!/usr/bin/env ruby
# record video of screen
# TODO fix playback speed

$res = "1600x900"

$filename = Time.new.strftime("%F-%H%M%S") + "_#{$res}_ffmpeg.webm"

#exec "ffmpeg -an -s #$res -r 25 -f x11grab -i :0.0 -vcodec libxvid #$filename"

# -i input
# -codec:v video encoder
# -quality encoding speed
# -cpu-used CPU encoding speed (lower is faster)
# -b:v video bitrate
# -qmin -qmax min/max quantization values
# -maxrate -bufsize upper limit for stream bitrate
# -threads
# -vf scale= resize video
# -an no audio
#exec "ffmpeg -f x11grab -s #$res -i :0.0 -codec:v libvpx -quality good -cpu-used 0 -b:v 1000k -qmin 10 -qmax 42 -maxrate 1000k -bufsize 2000k -threads 4 -vf scale=-1:#$p -an #$filename"
exec "ffmpeg -f x11grab -s #$res -r 60 -i :0.0 -codec:v libvpx -quality good -cpu-used 0 -b:v 1000k -qmin 10 -qmax 42 -maxrate 1000k -bufsize 2000k -threads 4 -an #$filename"
