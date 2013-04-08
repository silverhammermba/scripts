#!/usr/bin/env ruby
# symlink the awesome theme's background to a random one

require 'fileutils'

srand

theme_dir = File.expand_path('~/.config/awesome/themes/max')
background_dir = File.expand_path('~/pictures/backgrounds')
background = (Dir.entries(background_dir) - ['.', '..']).sample

FileUtils.rm_f File.join(theme_dir, 'background.png')
FileUtils.ln_s File.join(background_dir, background), File.join(theme_dir, 'background.png')
