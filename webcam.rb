#!/usr/bin/env ruby

$dev = "/dev/video0"
$res = "1280x720"

$filename = Time.new.strftime("%F-%H%M%S") + "_#{$res}_fswebcam.jpg"

exec "fswebcam --device #$dev --resolution #$res --no-banner #$filename"
