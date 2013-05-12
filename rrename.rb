#!/usr/bin/env ruby
# rename using regular expressions

require 'optparse'

$interactive = false
$clobber = true
$verbose = false

opts = OptionParser.new do |opts|
	opts.banner = "usage: #$0 [OPTIONS] PATTERN DESTINATION [FILES]"

	opts.separator "Match each file name against PATTERN. If successful, rename to DESTINATION."
	opts.separator "Interpolation is supported. Omit FILES to rename all in current directory."
	opts.separator ""
	opts.separator "Options:"

	opts.on('-h', '--help', 'print this message and exit') do
		puts opts
		exit
	end

	opts.on('-i', '--interactive', 'prompt before overwriting') do
		$interactive = true
		$clobber = false
	end

	opts.on('-n', '--no-clobber', 'do not overwrite an existing file') do
		$clobber = false
	end

	opts.on('-v', '--verbose', 'print messages') do
		$verbose = true
	end
end
opts.parse!

# process the rest of the arguments

if ARGV.length < 2
	STDERR.puts "#$0: missing arguments\nTry '#$0 --help' for more information."
	exit 1
end

begin
	$regexp = Regexp.new(ARGV[0])
rescue RegexpError
	STDERR.puts "ERROR: #$!"
	exit 1
end

$replace = ARGV[1]

$files = if ARGV.length > 2
		ARGV[2..-1]
	else
		Dir.entries('.') - ['.', '..']
	end

puts $regexp.inspect
puts $replace.inspect
puts $files.inspect

# do the work

$files.each do |file|
	if file =~ $regexp
		newfile = eval(?" + $replace + ?")

		if newfile != file
			rename = true

			if File.exists? newfile
				rename = false

				if $interactive
					STDERR.print "#$0: overwrite ‘#{newfile}’? "
					rename = true if gets.strip =~ /^y(es)?$/i
				elsif $clobber
					rename = true
				else
					puts "file exists:\t#{newfile}"
				end
			end

			if rename
				begin
					File.rename file, newfile
					puts "renamed\t#{file}:\t#{newfile}" if $verbose
				rescue SystemCallError
					puts "ERROR: #$!"
				end
			end
		elsif $verbose
			puts "new name is identical:\t#{file}"
		end
	elsif $verbose
		puts "no match:\t#{file}"
	end
end
