#!/usr/bin/env ruby
# record video of screen
# TODO reduce compression

$res = "1600x900"

$filename = Time.new.strftime("%F-%H%M%S") + "_#$res.avi"

# -an     no audio
# -s      frame size
# -r      fps
# -f      format
# -i      input file
# -vcodec video codec
exec "ffmpeg -an -s #$res -r 25 -f x11grab -i :0.0 -vcodec libxvid #$filename"
