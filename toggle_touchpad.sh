/usr/bin/synclient TouchpadOff=$(/usr/bin/synclient | ruby -ne 'p 1 - $1.to_i if /TouchpadOff\s*=\s*(\d+)/')
