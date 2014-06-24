
pop_size = 20

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

old_fit_avg  = old_fit. inject(&:+) / old_fit.length
old_time_avg = old_time.inject(&:+) / old_fit.length

new_fit_avg  = new_fit. inject(&:+) / new_fit.length
new_time_avg = new_time.inject(&:+) / new_fit.length

puts "Old:"
puts "Average fitness: #{old_fit_avg}"
puts "Average time:    #{old_time_avg}"

puts "New:"
puts "Average fitness: #{new_fit_avg}"
puts "Average time:    #{new_time_avg}"
