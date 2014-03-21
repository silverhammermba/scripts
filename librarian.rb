#!/usr/bin/env ruby
# general library organizing tool

require 'find'
require 'fileutils'

if ARGV.size < 2
  STDERR.puts <<-USAGE
usage: librarian OP [DIR [DIR ...]]
  where OP is

  ext   show/delete by file extension
  dir   remove empty dirs
USAGE
  exit 1
end

op = ARGV.shift

ops = {
  'ext' => proc { |library|
    extensions = {}

    Find.find(library) do |path|
      unless FileTest.directory? path
        ext = File.extname(path).downcase[1..-1]
        if ext.nil?
          ext = '"nil"'
        end
        extensions[ext] ||= []
        extensions[ext] << path
      end
    end

    puts "#{path} summary:"
    extensions.each { |ext, paths| puts "#{ext}\t#{paths.size}" }

    STDERR.print "Show which extension? "
    while ext = STDIN.gets
      ext = ext.strip.downcase
      if extensions[ext]
        puts extensions[ext]
        STDERR.print "Delete? [yN] "
        if del = STDIN.gets and del.strip =~ /^y(es)?$/i
          extensions[ext].each { |path| FileUtils.rm(path) }
          extensions.delete(ext)
        end
      else
        STDERR.puts "Unknown extension."
      end
      STDERR.print "Show which extension? "
    end

    puts
  },
  'dir' => proc { |library|
    # recursively remove empty directories

    remover = proc do
      removed = 0
      Find.find(library) do |path|
        if FileTest.directory?(path) and FileUtils.rmdir(path) and not Dir.exists?(path)
          removed += 1
          STDERR.puts "rmdir #{path}"
        end
      end
      removed
    end

    total = 0
    while (r = remover[]) > 0
      total += r
    end

    STDERR.puts "#{total} empty directories removed"
  }
}

unless ops[op]
  STDERR.puts "unrecognized operation: #{op}"
  exit 1
end

ARGV.each do |library|
  ops[op][library]
end
