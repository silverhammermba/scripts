#!/usr/bin/env ruby
# handle files snubbed by St. Peter

require 'fileutils'

conflicts = []

STDIN.each_line do |line|
  if line =~ /^ERROR: CONFLICT: /
    conflicts << {ops: [], dst: nil}
  elsif line =~ /^rm ERROR: (SRC|DST): (.*)/
    conflicts.last[:ops] << [:rm, $2]
  elsif line =~ /^mv ERROR: SRC: (.*)/
    conflicts.last[:ops] << [:mv, $1]
  end
  if conflicts.last and not conflicts.last[:dst] and line =~ /^(\w+ )?ERROR: DST: (.*)/
    conflicts.last[:dst] = File.dirname($2)
  end
end

# add destination to move ops
conflicts.each { |c| c[:ops].each { |op| op << c[:dst] if op[0] == :mv } }

conflicts.each { |c| c[:ops].each { |op| STDERR.puts op.join(' '); FileUtils.send(*op) } }
