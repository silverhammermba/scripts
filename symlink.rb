#!/usr/bin/env ruby
# easier absolute symlinks

if ARGV.length != 2
	STDERR.puts "usage: #$0 TARGET LINK
create absolute symlink to TARGET named LINK. If LINK is a directory, name
symlink after TARGET, minus any file extension"
end

target = File.expand_path(ARGV[0])
link = ARGV[1]

if Dir.exists? link
	link = File.join(link, File.basename(target).split(?., 2).first)

	if Dir.exists? link
		raise Errno::EEXIST.new(link)
	end
end

require 'fileutils'

FileUtils.ln_s(target, link)
