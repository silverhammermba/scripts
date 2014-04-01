#!/usr/bin/env ruby
# if you want to get into heaven, you need to go through this guy

require 'find'
require 'taglib'
require 'set'
require 'fileutils'

def edit_distance(s, t)
  m = s.length
  n = t.length
  return m if n == 0
  return n if m == 0
  d = Array.new(m+1) {Array.new(n+1)}

  (0..m).each {|i| d[i][0] = i}
  (0..n).each {|j| d[0][j] = j}
  (1..n).each do |j|
    (1..m).each do |i|
      d[i][j] = if s[i-1] == t[j-1]  # adjust index into string
        d[i-1][j-1]       # no operation required
      else
        [ d[i-1][j]+1,    # deletion
          d[i][j-1]+1,    # insertion
          d[i-1][j-1]+1,  # substitution
        ].min
      end
    end
  end
  d[m][n]
end

if ARGV.length != 2
  STDERR.puts "usage: #$0 EARTH HEAVEN"
  exit 1
end

earth = File.expand_path(ARGV[0])
heaven = File.expand_path(ARGV[1])

known_exts = Set.new [
  '.mp3',
  '.m4a',
  '.ogg',
  '.flac'
]

sinners = []

# collect files with known extensions
Find.find(earth) do |path|
  next if File.directory? path
  sinners << path if known_exts.include? File.extname(path).downcase
end

exit if sinners.empty?

# get existing library info
$library = {}

Find.find(heaven) do |path|
  next if File.directory? path
  TagLib::FileRef.open(path) do |f|
    $library[f.tag.artist] ||= Set.new
    $library[f.tag.artist] << f.tag.album
  end
end

# try to correct artist names not in library
def check_artist artist, paths
  # if this is a new artist
  unless $library[artist]
    # look for similar existing artist names

    STDERR.puts "Unrecognized artist: #{artist}"
    distances = $library.keys.map { |a| [a, edit_distance(a, artist)] }
    min = distances.min_by(&:last)
    matches = distances.select { |a, d| d == min }.map(&:first)

    unless matches.empty?
      STDERR.puts "Closest matches:"
      matches.each { |a| puts "\t#{a}" }
    end
    # prompt for new one
    STDERR.print "Change artist name? "
    new = STDIN.gets.strip

    # if new name set
    if not new.empty? and new != artist
      artist = new
      STDOUT.puts "ACTION: Updating artist to: #{artist}"

      # update songs
      paths.each do |path|
        TagLib::FileRef.open(path) do |f|
          f.tag.artist = artist
          f.save
        end
      end
    end

    # add library record
    $library[artist] ||= Set.new
  end

  artist
end

# check and correct duplicate/incorrect album names
def check_album artist, album, paths
  # if this is a new album
  unless $library[artist].include? album
    # look for similar existing album names
    STDERR.puts "New album: #{album}"
    distances = $library[artist].map { |a| [a, edit_distance(a, album)] }
    min = distances.min_by(&:last)
    matches = distances.select { |a, d| d == min }.map(&:first)

    unless matches.empty?
      STDERR.puts "Closest matches:"
      matches.each { |a| puts "\t#{a}" }
    end
    # prompt for new one
    STDERR.print "Change album name? "
    new = STDIN.gets.strip

    # if new name set
    if not new.empty? and new != album
      album = new
      STDOUT.puts "ACTION: Updating album to: #{album}"

      # update songs
      paths.each do |path|
        TagLib::FileRef.open(path) do |f|
          f.tag.album = album
          f.save
        end
      end
    end
  end

  if $library[artist].include? album
    STDOUT.puts "ERROR: Duplicate album: #{album}"
    return nil
  end

  $library[artist] << album
  album
end

# handle songs by directory
sinners.group_by { |path| File.dirname(path) }.each do |dir, paths|
  # handle stray songs individually
  if dir == earth
    STDOUT.puts "LOG: Processing #{dir}"
    paths.each do |path|
      artist, album = TagLib::FileRef.open(path) { |f| f.null? ? nil : [f.tag.artist, f.tag.album] }
      unless artist
        STDOUT.puts "ERROR: No artist information for #{path}"
        next
      end
      unless album
        STDOUT.puts "ERROR: No album information for #{path}"
        next
      end

      artist = check_artist(artist, [path])
      album = check_album(artist, album, [path])
      next unless album

      # good to go now
      dest = File.join(heaven, artist, album)
      STDOUT.puts "ACTION: Moving #{path} to #{dest}"
      FileUtils.mkdir_p(dest)
      FileUtils.mv(path, dest)
    end
  else
    # only import if we get one artist, one album
    artists = paths.map { |path| TagLib::FileRef.open(path) { |f| f.null? ? nil : f.tag.artist } }.uniq
    if artists.size > 1
      STDOUT.puts "ERROR: Multiple artists in #{dir}"
      next
    elsif artists.first.nil?
      STDOUT.puts "ERROR: No artists information for #{dir}"
      next
    end
    artist = artists.first

    albums = paths.map { |path| TagLib::FileRef.open(path) { |f| f.null? ? nil : f.tag.album } }.uniq
    if albums.size > 1
      STDOUT.puts "ERROR: Multiple albums in #{dir}"
      next
    elsif albums.first.nil?
      STDOUT.puts "ERROR: No album information for #{dir}"
      next
    end
    album = albums.first

    STDOUT.puts "LOG: Processing #{dir}"

    artist = check_artist(artist, paths)
    album = check_album(artist, album, paths)
    next unless album

    # go, go, go!
    dest = File.join(heaven, artist, album)
    STDOUT.puts "ACTION: Moving #{dir} tracks to #{dest}"
    FileUtils.mkdir_p(dest)
    paths.each { |path| FileUtils.mv(path, dest) }

    # look for leftover crap
    if Dir.entries(dir).size > 2
      STDOUT.puts "WARNING: Leftover files in #{dir}"
    end
  end
end

empty = 1

while empty > 0
  empty = 0
  Find.find(earth) do |path|
    next unless File.directory? path
    FileUtils.rmdir path
    unless File.exists? path
      STDOUT.puts "ACTION: Removing empty dir #{path}"
      empty += 1
    end
  end
end
