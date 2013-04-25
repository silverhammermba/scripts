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
	# return array of arrays of rolls
	(1..times).map do
		rolls = (1..number).map { 1 + rand(sides) }
		rolls << modifier if modifier != 0
		rolls
	end
end

def display results
	# TODO print in columns with cmds as headers?
	results.each do |rolls|
		str = rolls.map { |r| "%+d" % r }.join
		str = str[1..-1] if str[0] == ?+
		str += " = #{rolls.reduce(:+)}" if rolls.length > 1
		puts str
	end
end

if ARGV.empty? or ARGV.include?('-h') or ARGV.include?('--help')
	STDERR.puts "usage: #{$0} ROLL
where ROLL is formatted as [Tx][N]dS[+-M]
	T	number of times to repeat roll
	N	number of dice per roll
	S	number of sides per die
	M	modifier to add to roll total"
	exit 1
end

ARGV.each do |cmd|
	display(roll(*parse(cmd.strip)))
end
