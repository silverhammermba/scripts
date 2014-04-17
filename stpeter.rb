#!/usr/bin/env ruby
# if you want to get into heaven, you need to go through this guy

require 'find'
require 'taglib'
require 'set'
require 'fileutils'

# for suggesting existing artist/album names
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

# how library files are organized
def dest artist, album
  File.join($heaven, artist, album)
end

$copy = false
$copy = true if ARGV.delete('--copy') or ARGV.delete('-c')

if ARGV.length != 2
  STDERR.puts "usage: #$0 EARTH HEAVEN"
  exit 1
end

$earth = File.expand_path(ARGV[0])
$heaven = File.expand_path(ARGV[1])

known_exts = Set.new [
  '.mp3',
  '.m4a',
  '.ogg',
  '.flac'
]

sinners = []

# collect files with known extensions
Find.find($earth) do |path|
  next if File.directory? path
  sinners << path if known_exts.include? File.extname(path).downcase
end

exit if sinners.empty?

# get existing library info
$library = {}

Find.find($heaven) do |path|
  next if File.directory? path
  TagLib::FileRef.open(path) do |f|
    artists = f.tag.artist.split(' / ')
    artists.each { |artist| $library[artist] ||= Set.new }
    $library[artists.first] << f.tag.album
  end
end

# try to correct artist names not in library
def check_artists artists
  # collect all artist names
  all = artists.map(&:last).reduce(:+).uniq
  new_name = {}

  # check each artist
  all.each do |artist|
    # if this is a new artist
    unless $library[artist]
      # look for similar existing artist names

      STDERR.puts "Unrecognized artist: #{artist}"
      distances = $library.keys.map { |a| [a, edit_distance(a, artist)] }
      min = distances.min_by(&:last)
      matches = distances.select { |a, d| d == min[1] }.map(&:first)

      unless matches.empty?
        STDERR.puts "Closest matches:"
        matches.each { |a| puts "\t#{a}" }
      end
      # prompt for new one
      STDERR.print "Change artist name? "
      new = STDIN.gets.strip

      # if new name set
      if not new.empty? and new != artist
        new_name[artist] = new
        artist = new
      end

      # add library record
      $library[artist] ||= Set.new
    end
  end

  changes = {}

  # update songs
  artists.each do |path, a|
    # skip if we didn't change anything
    next unless a.any? { |artist| new_name[artist] }
    changes[path] = a.map { |artist| new_name[artist] || artist }.join(' / ')
  end

  primary = artists[0][1][0]
  # return primary artist name and changes to make
  return [new_name[primary] || primary, new_name, changes]
end

# check and correct duplicate/incorrect album names
def check_album artist, album, paths
  changes = {}

  # if this is a new album
  unless $library[artist].include? album
    # look for similar existing album names
    STDERR.puts "New album: #{album}"
    distances = $library[artist].map { |a| [a, edit_distance(a, album)] }
    min = distances.min_by(&:last)
    matches = distances.select { |a, d| d == min[1] }.map(&:first)

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

      # update songs
      paths.each do |path|
        changes[path] = album
      end
    end
  end

  if $library[artist].include? album
    STDOUT.puts "ERROR: CONFLICT: Duplicate album: #{album}"
    paths.each { |path| STDOUT.puts "ERROR: SRC: #{path}" }
    Find.find(dest(artist, album)) { |path| STDOUT.puts "ERROR: DST: #{path}" unless File.directory? path }
    return [nil, changes]
  end

  $library[artist] << album
  return [album, changes]
end

def update path, artist_changes, album_changes
  if artist_changes[path] or album_changes[path]
    TagLib::FileRef.open(path) do |f|
      f.tag.artist = artist_changes[path] if artist_changes[path]
      f.tag.album = album_changes[path] if album_changes[path]
      f.save
    end
  end
end

# handle songs by directory
sinners.group_by { |path| File.dirname(path) }.each do |dir, paths|
  # handle stray songs individually
  if dir == $earth
    STDOUT.puts "LOG: Processing #{dir}"
    paths.each do |path|
      artists, album = TagLib::FileRef.open(path) { |f| f.null? ? nil : [f.tag.artist.split(' / '), f.tag.album] }
      unless artists
        STDOUT.puts "ERROR: No artist information for #{path}"
        next
      end

      STDOUT.puts "LOG: Processing #{path}"

      # try to fix artist/album
      artist, new_artists, artist_changes = check_artists([[path, artists]])
      if album
        album, album_changes = check_album(artist, album, [path])
        next unless album
        dst = dest(artist, album)
      else
        STDOUT.puts "LOG: No album information for #{path}"
        dst = File.join($heaven, artist)
      end

      # show new values
      unless new_artists.empty?
        STDOUT.puts "ACTION: Updating artists:"
        new_artists.each { |o, n| puts "ACTION:\t#{o} -> #{a}" }
      end
      if album_changes and not album_changes.empty?
        STDOUT.puts "ACTION: Updating album to: #{album}"
      end

      # allow bailout
      STDERR.print "Continue? [Yn] "
      next if STDIN.gets.strip =~ /^no?$/

      # good to go now
      update(path, artist_changes, album_changes)

      STDOUT.puts "ACTION: Moving #{path} to #{dst}"
      FileUtils.mkdir_p(dst)
      FileUtils.mv(path, dst)
    end
  else
    # only import if we get one artist, one album
    artists = paths.map { |path| TagLib::FileRef.open(path) { |f| [path, f.null? ? nil : f.tag.artist.split(' / ')] } }
    if artists.map { |path, a| a.first }.uniq.size > 1
      STDOUT.puts "ERROR: Multiple primary artists in #{dir}"
      next
    elsif artists[0][1].nil?
      STDOUT.puts "ERROR: No artist information for #{dir}"
      next
    end

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

    # try to fix artist/album
    artist, new_artists, artist_changes = check_artists(artists)
    album, album_changes = check_album(artist, album, paths)
    next unless album

    # show new values
    unless new_artists.empty?
      STDOUT.puts "ACTION: Updating artists:"
      new_artists.each { |o, n| puts "ACTION:\t#{o} -> #{n}" }
    end
    unless album_changes.empty?
      STDOUT.puts "ACTION: Updating album to: #{album}"
    end

    # allow bailout
    STDERR.print "Continue? [Yn] "
    next if STDIN.gets.strip =~ /^no?$/

    # go, go, go!
    paths.each { |path| update(path, artist_changes, album_changes) }

    dst = dest(artist, album)
    STDOUT.puts "ACTION: Moving #{dir} tracks to #{dst}"
    FileUtils.mkdir_p(dst)
    paths.each { |path| FileUtils.mv(path, dst) }

    # look for leftover crap
    if Dir.entries(dir).size > 2
      STDOUT.puts "WARNING: Leftover files in #{dir}"
    end
  end
end

empty = 1

while empty > 0
  empty = 0
  Find.find($earth) do |path|
    next unless File.directory? path
    FileUtils.rmdir path
    unless File.exists? path
      STDOUT.puts "ACTION: Removing empty dir #{path}"
      empty += 1
    end
  end
end
