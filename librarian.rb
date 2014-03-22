#!/usr/bin/env ruby
# general library organizing tool

require 'find'
require 'fileutils'
require 'taglib'

# create a numbered menu for a hash, with block for optional styling
def menu hash, prompt
  hash.each_with_index do |pair, i|
    puts "#{i + 1}.\t#{block_given? ? yield(pair) : pair[0]}"
  end

  STDERR.print prompt
  input = STDIN.gets

  # get input until the user cancels or we get a selection
  until input.nil? or (input.strip =~ /^(\d+)$/ and (1..hash.size) === (input = $1.to_i))
    STDERR.puts "Invalid selection."
    STDERR.print prompt
    input = STDIN.gets
  end

  if input.nil?
    STDERR.puts
    return nil
  end

  hash.find.with_index { |pair, i| i + 1 == input }
end

if ARGV.size < 2
  STDERR.puts <<-USAGE
usage: librarian OP [DIR [DIR ...]]
  where OP is

  ext   show/delete by file extension
  dir   remove empty dirs
  id3   music tag analysis
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
  },

  'id3' => proc { |library|
    artists = {}

    normalize = proc { |n| n.gsub(/[^\w ]/, '') }

    # build hash of artists grouped by normalized artist name
    Find.find(library) do |path|
      unless FileTest.directory?(path)
        TagLib::FileRef.open(path) do |f|
          if not f.null? and f.tag.artist
            n = normalize[f.tag.artist]
            artists[n] ||= {}
            artists[n][f.tag.artist] ||= []
            artists[n][f.tag.artist] << path
          end
        end
      end
    end

    # get rid of unique matches
    artists.reject! { |a, h| h.size == 1 }

    # nothing to do
    if artists.empty?
      STDERR.puts "No near-duplicate artists"
      next
    end

    while true
      _, arts = menu(artists, "Examine which artist? ") { |n, a| "(#{a.size})\t#{n}" }
      break unless arts
      artist, _ = menu(arts, "Use which artist name? ") { |a, p| "(#{p.size})\t#{a}" }
      break unless artist
      STDERR.puts "Setting all artists to: #{artist}"
      arts.each do |art, paths|
        if art != artist
          paths.each do |path|
            STDERR.puts "Processing: #{path}"
            TagLib::FileRef.open(path) do |f|
              f.tag.artist = artist
              f.save
            end
          end
        end
      end
    end
  }
}

unless ops[op]
  STDERR.puts "unrecognized operation: #{op}"
  exit 1
end

ARGV.each do |library|
  ops[op][library]
end
