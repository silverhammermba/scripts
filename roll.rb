#!/usr/bin/env ruby
# dice rolling from the command line
# e.g. 2x3d6+4, d6

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

if ARGV.empty? or ARGV.include?('-h') or ARGV.include?('--help')
	STDERR.puts <<USAGE
USAGE: #$0 ROLL
where ROLL is formatted as [Tx][N]dS[+-M]
	T	number of times to repeat roll
	N	number of dice per roll
	S	number of sides per die
	M	modifier to add to roll total

OPTIONS
	--pdf -p  print probabilities of roll outcomes
	--gt  -g  print probabilities of rolling >= each outcome
	--lt  -l  print probabilities of rolling <= each outcome

EXAMPLES
	#$0 d20+2  roll one 20-sided die and add two to the result
	#$0 4x3d6  roll three 6-sided dice four times
USAGE

	exit 1
end

$pdf = ARGV.delete('-p') || ARGV.delete('--pdf')
$gt = ARGV.delete('-g') || ARGV.delete('--gt')
$lt = ARGV.delete('-l') || ARGV.delete('--lt')

ARGV.each do |cmd|
	roll = Roll.new(cmd)

	if $pdf
		puts "Roll"
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
