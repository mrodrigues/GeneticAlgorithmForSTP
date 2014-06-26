
module Enumerable
  def sum
    return self.inject(0){|accum, i| accum + i }
  end

  def mean
    return self.sum / self.length.to_f
  end

  def sample_variance
    m = self.mean
    sum = self.inject(0){|accum, i| accum + (i - m) ** 2 }
    return sum / (self.length - 1).to_f
  end

  def standard_deviation
    return Math.sqrt(self.sample_variance)
  end
end

pop_size = ARGV[0] || 20

old_fit  = []
old_time = []

new_fit  = []
new_time = []

regex = /fitness: (\d+)\n.*\( ?(\d+\.\d+)\)\n/

10.times do |i|
  str = File.open("results/pop_#{pop_size}/testes-old/result_#{i}.txt").read
  str =~ regex
  old_fit << $1.to_f
  old_time << $2.to_f

  str = File.open("results/pop_#{pop_size}/testes-new/result_#{i}.txt").read
  str =~ regex
  new_fit << $1.to_f
  new_time << $2.to_f
end

puts "Old:"
puts "Average fitness:             #{old_fit.mean}"
puts "Best fitness:                #{old_fit.min}"
puts "Fitness standard devitation: #{old_fit.standard_deviation}"
puts "Average time:                #{old_time.mean}"
puts "Time standard deviation:     #{old_time.standard_deviation}"
puts

puts "New:"
puts "Average fitness:             #{new_fit.mean}"
puts "Best fitness:                #{new_fit.min}"
puts "Fitness standard devitation: #{new_fit.standard_deviation}"
puts "Average time:                #{new_time.mean}"
puts "Time standard deviation:     #{new_time.standard_deviation}"
