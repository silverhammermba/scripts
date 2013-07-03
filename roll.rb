#!/usr/bin/env ruby
# dice rolling from the command line
# e.g. 2x3d6+4, d6

require 'optparse'

def bar num, val, den, total, col_width, width
	puts "%#{col_width}d: #{?□ * ((val * width) / den)} %.2f%%" % [num, val * 100.0 / total]
end

# class for rolling a number of same-sided dice
class Dice
	@@counts = {}

	# number of ways to roll total with number side-sided dice
	def self.ways number, sides, total
		return 0 if total < number or total > number * sides
		return 1 if number == 1
		@@counts[[number, sides, total]] ||= (1..total).map { |r| ways(1, sides, r) * ways(number - 1, sides, total - r) }.reduce(:+)
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

	def self.ways dice, signs, total
		if dice.length == 1
			return dice[0].ways(total * signs[0])
		end

		if signs[0] > 0
			range = (dice[0].min..dice[0].max)
		else
			range = (-(dice[0].max)..-(dice[0].min))
		end

		w = range.map { |t| ways(dice[1..-1], signs[1..-1], total - t) }.reduce(:+)

		return w
	end

	def dist
		return @dist if @dist

		min = @dice.zip(@signs).map { |d, s| s > 0 ? d.min : -(d.max) }.reduce(:+)
		max = @dice.zip(@signs).map { |d, s| s > 0 ? d.max : -(d.min) }.reduce(:+)

		@dist = Hash.new(0)

		(min..max).each do |t|
			@dist[t] = self.class.ways(@dice, @signs, t)
		end

		@dist
	end

	def pdf
		kmin = dist.keys.min
		kmax = dist.keys.max

		max = dist.values.max
		total = dist.values.reduce(:+)

		col = [kmin, kmax].map { |k| k.to_s.size }.max

		(kmin..kmax).each do |i|
			bar(i, dist[i], max, total, col, $width)
		end
	end

	def cdf meth
		min = dist.keys.min
		max = dist.keys.max
		total = dist.values.reduce(:+)

		col = [min, max].map { |k| k.to_s.size }.max

		(min..max).each do |i|
			t = 0
			(min..max).each do |j|
				t += dist[j] if j.send(meth, i)
			end
			bar(i, t, total, total, col, $width)
		end
	end
end

$width = 80

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
		puts "== Roll"
		roll.pdf
	end

	if $gt
		puts ">= Roll"
		roll.cdf(:>=)
	end

	if $lt
		puts "<= Roll"
		roll.cdf(:<=)
	end

	if not ($pdf or $gt or $lt)
		roll.result
	end
end
