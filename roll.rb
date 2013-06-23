#!/usr/bin/env ruby
# dice rolling from the command line
# e.g. 2x3d6+4, d6

require 'optparse'

# TODO proper arg parsing

class Hash
	def histogram
		min = keys.min
		max = keys.max
	end
end

# class for rolling a number of same-sided dice
class Dice
	@@counts = {}

	# number of ways to roll total with number side-sided dice
	def self.ways number, sides, total
		return 0 if total < number or total > number * sides
		return 1 if number == 1
		return @@counts[[number, sides, total]] ||= (1..(total - number + 1)).map { |r| ways(number - 1, sides, total - r) }.reduce(:+)
	end

	def initialize number, sides
		@number = number
		@sides = sides
	end

	def min
		@number
	end

	def max
		@number * @sides
	end

	def ways total
		self.class.ways @number, @sides, total
	end

	def roll
		(1..@number).map { 1 + rand(@sides) }
	end
end

class Roll
	def initialize str
		@str = str

		@times = 1
		if str =~ /^(\d+)x(.*)/
			@times = $1.to_i
			str = $2
		end

		@modifier = 0
		if str =~ /(.*)([+-]\d+)$/
			@modifier = $2.to_i
			str = $1
		end

		@dice = []
		@signs = []
		first = true

		while str =~ /^([+-])?(\d+)?d(\d+)(.*)$/
			if $1
				@signs << ($1 + ?1).to_i
			elsif first # assume positive if no sign before first dice
				@signs << 1
			else
				raise ArgumentError.new("missing sign before `#{str}'")
			end
			first = false

			number = 1
			if $2
				number = $2.to_i
			end

			@dice << Dice.new(number, $3.to_i)

			str = $4
		end

		unless str.empty?
			raise ArgumentError.new("couldn't parse `#{str}'")
		end
	end

	attr_reader :times, :number, :sides, :modifier

	def result
		(1..@times).each do
			rolls = @dice.zip(@signs).map { |d, s| d.roll.map { |r| r * s } }.flatten
			rolls << @modifier if @modifier != 0
			str = rolls.map { |r| "%+d" % r }.join
			str = str[1..-1] if str[0] == ?+
			str += " = #{rolls.reduce(:+)}" if rolls.length > 1
			puts str
		end
	end

	def to_s
		@str
	end

	# no @times
	def to_short_s
		s = "d#@sides"
		s = "#@number#{s}" if @number != 1
		s += "%+d" % @modifier if @modifier != 0
		s
	end

	def dist
		return @dist if @dist

		die = (1..@sides).to_a
		@dist = Hash.new(0)
		if @number == 1
			die.each { |s| @dist[s + @modifier] += 1 }
		else
			die.product(*Array.new(@number - 1, die)).each do |s|
				@dist[s.reduce(:+) + @modifier] += 1
			end
		end

		@dist
	end

	# TODO use new Dice class
	def pdf
		max = dist.values.max
		total = dist.values.reduce(:+)

		dist.keys.sort.each do |i|
			puts "%2d: #{?# * ((dist[i] * 80) / max)} %.2f%%" % [i, dist[i] * 100.0 / total]
		end
	end

	def cdf meth
		min = dist.keys.min
		max = dist.keys.max
		total = dist.values.reduce(:+)

		(min..max).each do |i|
			t = 0
			(min..max).each do |j|
				t += dist[j] if j.send(meth, i)
			end
			puts "%2d: #{?# * ((t * 80) / total)} %.2f%%" % [i, t * 100.0 / total]
		end
	end
end

OptionParser.new do |opts|
	opts.banner = "USAGE: #$0 ROLL [OPTIONS]"
	opts.separator <<ROLL
where ROLL is formatted as [Tx][N]dS[+-M]"
	T	number of times to repeat roll
	N	number of dice per roll
	S	number of sides per die
	M	modifier to add to roll total

OPTIONS
ROLL

	opts.on('-p', '--pdf', "print probabilities of roll outcomes") do |p|
		$pdf = true
	end

	opts.on('-g', '--greater', "print probabilities of rolling >= each value") do |g|
		$gt = true
	end

	opts.on('-l', '--less', "print probabilities of rolling <= each value") do |g|
		$lt = true
	end
end.parse!

ARGV.each do |cmd|
	roll = Roll.new(cmd)

	if $pdf
		puts "Roll #{roll.to_short_s}"
		roll.pdf
	end

	if $gt
		puts ">= Roll #{roll.to_short_s}"
		roll.cdf(:>=)
	end

	if $lt
		puts "<= Roll #{roll.to_short_s}"
		roll.cdf(:<=)
	end

	if not ($pdf or $gt or $lt)
		roll.result
	end
end
