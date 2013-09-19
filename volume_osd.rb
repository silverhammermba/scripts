#!/usr/bin/env ruby
# display volume information using notify-send

`amixer get Master` =~ /\[(\d+)%\] \[.*\] \[(on|off)\]/

$level = if $2 == "off"
	:muted
else
	case $1.to_i
	when 0...25
		:off
	when 25...50
		:low
	when 50...75
		:medium
	when 75..100
		:high
	end
end

`notify-send " " -i notification-audio-volume-#$level -h int:value:#$1 -h string:synchronous:volume`
