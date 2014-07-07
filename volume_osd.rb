#!/usr/bin/env ruby
# display volume information using notify-send

$volume = `ponymix get-volume`.to_i
muted = system 'ponymix is-muted'

$level =
case $volume
when 0...25
  :off
when 25...50
  :low
when 50...75
  :medium
when 75..100
  :high
end

$level = :muted if muted

`notify-send " " -i notification-audio-volume-#$level -h int:value:#$volume -h string:synchronous:volume`
