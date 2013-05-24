#!/usr/bin/env ruby
# check/download updates to AUR packages

require 'net/https'
require 'nokogiri'
require 'tempfile'

$build_dir = '~/.builds'
$build_dir = File.expand_path($build_dir)

def check pkg, ver
	# check if a newer version of the package exists
	response = Net::HTTP.get_response(URI("https://aur.archlinux.org/packages/#{pkg}"))

	if response.is_a? Net::HTTPSuccess
		document = Nokogiri::HTML(response.body)

		if document.css('#pkgdetails > h2')[0].text =~ /#{pkg}\s+(.*)/
			if ver < $1
				puts "#{pkg}: #{ver} -> #$1"
				return document.css('#actionlist li a')[-1]["href"]
			end
		else
			STDERR.puts "#{pkg}: failed to parse page"
		end
	else
		STDERR.puts "#{pkg}: failed to retrieve page"
	end
end

def download tar
	response = Net::HTTP.get_response(URI('https://aur.archlinux.org' + tar))

	if response.is_a? Net::HTTPSuccess
		tmp = Dir::Tmpname.make_tmpname(['pkg', '.tar.gz'], nil)
		open(tmp, 'wb') { |file| file.write(response.body) }
		return tmp
	else
		STDERR.puts "failed to download #{tar}"
	end
end

`pacman -Qm`.each_line do |line|
	pkg, ver = line.split

	if tar = check(pkg, ver)
		print "Retrieve package? [yN] "
		if gets.strip =~ /^y(es)?$/i
			tmp = download(tar)
			unless system "tar -xf #{tmp} -C #$build_dir"
				STDERR.puts "failed to extract package"
			end
			FileUtils.rm(tmp)
		end
	end
end
