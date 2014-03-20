#!/usr/bin/env ruby
# general library organizing tool

require 'find'
require 'fileutils'

library = ARGV[0]

extensions = {}

Find.find(library) do |path|
  unless FileTest.directory? path
    ext = File.extname(path).downcase[1..-1]
    extensions[ext] ||= []
    extensions[ext] << path
  end
end

puts "Summary:"
extensions.each { |ext, paths| puts "#{ext}\t#{paths.size}" }

STDERR.print "Show which extension? "
while ext = STDIN.gets
  ext = ext.strip.downcase
  if extensions[ext]
    puts extensions[ext]
    STDERR.print "Delete? [yN] "
    if STDIN.gets.strip =~ /^y(es)?$/i
      extensions[ext].each { |path| FileUtils.rm(path) }
      extensions.delete(ext)
    end
  else
    STDERR.puts "Unknown extension."
  end
  STDERR.print "Show which extension? "
end

puts
