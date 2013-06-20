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

class Roll
	def initialize str
		@str = str.strip
		raise ArgumentError.new("Bad roll string: #@str") unless @str =~ /^((\d+)x)?(\d+)?d(\d+)([+-]\d+)?$/
		@times = 1
		@times = $2.to_i if $2
		@number = 1
		@number = $3.to_i if $3
		@sides = $4.to_i
		@modifier = 0
		@modifier = $5.to_i if $5
	end

	attr_reader :times, :number, :sides, :modifier

	def result
		(1..@times).each do
			rolls = (1..@number).map { 1 + rand(@sides) }
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
