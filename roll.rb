#!/usr/bin/env ruby
# dice rolling from the command line
# e.g. 2x3d6+4, d6

def parse str
	raise ArgumentError.new("Bad roll string: #{str}") unless str =~ /^((\d+)x)?(\d+)?d(\d+)([+-]\d+)?$/
	times = 1
	times = $2.to_i if $2
	number = 1
	number = $3.to_i if $3
	sides = $4.to_i
	modifier = 0
	modifier = $5.to_i if $5
	[sides, number, modifier, times]
end

def roll sides, number = 1, modifier = 0, times = 1
	times.times do
		rolls = (1..number).map { 1 + rand(sides) }
		str = rolls.join(?+)
		str += "%+d" % modifier if modifier != 0
		str += " = #{rolls.reduce(:+) + modifier}" % modifier if modifier != 0 or number > 1
		puts str
	end
end

ARGV.each do |cmd|
	roll(*parse(cmd.strip))
end
