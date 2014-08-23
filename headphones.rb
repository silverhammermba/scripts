#!/usr/bin/env ruby
# toggle between speakers and headphones

frnt = `amixer -c PCH get Front`[/(\d+)%/, 1].to_i
head = `amixer -c PCH get Headphone`[/(\d+)%/, 1].to_i


if frnt > 0
  `amixer -c PCH set Front 0%`
  `amixer -c PCH set Headphone 60%`
  source = 'headphones'
else
  `amixer -c PCH set Headphone 0%`
  `amixer -c PCH set Front 100%`
  source = 'speakers'
end
`amixer -c PCH set Master 100%`

`notify-send 'Enabling #{source}' --icon=multimedia-volume-control`
