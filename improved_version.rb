require 'benchmark'
require 'pry'
require 'pry-debugger'
# Genetic Algorithm in the Ruby Programming Language

# The Clever Algorithms Project: http://www.CleverAlgorithms.com
# (c) Copyright 2010 Jason Brownlee. Some Rights Reserved. 
# This work is licensed under a Creative Commons Attribution-Noncommercial-Share Alike 2.5 Australia License.


def putm(matrix)
  matrix.each do |row|
    puts row.inspect
  end
end

def print_tt(timetable)
  puts "class:"
  putm(timetable[:class])

  puts "teacher"
  putm(timetable[:teacher])
end

# =========================================

def tournament_selection(population, tournment_size, num_periods, num_venues)
  winner = rand(population.size)

  (1...tournment_size).each do
    current = rand(population.size)

    while current == winner
      current = rand(population.size)
    end

    if (rand(3) % 3 == 0)
      if population[current][:fitness] < population[winner][:fitness]
        winner = current
      end
    elsif (rand(3) % 3 == 1)
      winner = current
    # else winner is not changed 
    end
  end

  new_individual = copy_timetable(population[winner], num_periods, num_venues)
  new_individual[:fitness] = fitness(new_individual, num_periods, num_venues)

  return new_individual
end

def new_row(value, period, first_venue, second_venue)
  { value: value, period: period, venues: [first_venue, second_venue] }
end

def find_period_with_clash(sub_timetable, num_periods, num_venues, options = {})
  excluded = options[:excluded] || []
  venues   = options[:venues]   || []
  venues_range = venues.empty? ? (0...num_venues) : venues
  for i in 0...num_periods
    if !excluded.include?(i)
      for j in venues_range
        value = sub_timetable[i][j]
        for venue in 0...num_venues
          if venue != j && sub_timetable[i][venue] == value
            return new_row(value, i, j, venue)
          end
        end
      end
    end
  end
  return nil
end

def find_missing(sub_timetable, period, num_venues, elements)
  missing = (0...elements).to_a
  for j in 0...num_venues
    missing.delete(sub_timetable[period][j])
  end

  return missing.first
end

def swap(first_clash, second_clash, sub_timetable)
  venue = (first_clash[:venues] & second_clash[:venues]).first
  sub_timetable[ first_clash[:period]][venue] = second_clash[:value]
  sub_timetable[second_clash[:period]][venue] = first_clash[:value]
end

def random_row(sub_timetable, num_periods, first_clash)
  period = ((0...num_periods).to_a - [first_clash[:period]]).sample
  venue = first_clash[:venues].sample
  value = sub_timetable[period][venue]
  new_row(value, period, venue, venue)
end

def mutate!(timetable, mutation_swaps, num_periods, num_venues, num_classes, num_teachers)
  mutation_swaps.times do |i|
    type = rand < 0.5 ? :class : :teacher
    sub_timetable = timetable[type]
    if (first_clash = find_period_with_clash(sub_timetable, num_periods, num_venues))
      missing = find_missing(sub_timetable,
                             first_clash[:period],
                             num_venues,
                             type == :class ? num_classes : num_teachers)

      excluded = [first_clash[:period]]
      swapped = false
      has_rows_with_clash = true
      while !swapped && has_rows_with_clash && excluded.size < sub_timetable.size
        second_clash = find_period_with_clash(
          sub_timetable,
          num_periods,
          num_venues,
          excluded: excluded,
          venues: first_clash[:venues]
        )
        if second_clash
          if second_clash[:value] == missing
            swap(first_clash, second_clash, sub_timetable)
            swapped = true
          else
            excluded << second_clash[:period]
          end
        else
          has_rows_with_clash = false
        end
      end

      if !swapped
        swap(first_clash, random_row(sub_timetable, num_periods, first_clash), sub_timetable)
      end
    end
  end
end

def crossover(parent1, parent2, rate, num_periods, num_venues)
  return copy_timetable(parent1, num_periods, num_venues) if rand >= rate
  point = 1 + rand(num_venues - 2)
  child = new_timetable(num_periods, num_venues)
  for i in 0...num_periods
    for j in 0...num_venues
      parent = j < point ? parent1 : parent2
      child[:class  ][i][j] = parent[:class  ][i][j]
      child[:teacher][i][j] = parent[:teacher][i][j]
    end
  end
  return child
end

def copy_timetable(timetable, num_periods, num_venues)
  copy = new_timetable(num_periods, num_venues)
  for i in 0...num_periods
    for j in 0...num_venues
      copy[:class  ][i][j] = timetable[:class  ][i][j]
      copy[:teacher][i][j] = timetable[:teacher][i][j]
    end
  end
  copy
end

def reproduce(selected, mutation_swaps, num_periods, num_venues, num_classes, num_teachers)
  selected.sort_by! {|timetable| timetable[:fitness] = fitness(timetable, num_periods, num_venues) }

  children = []
  selected.each_with_index do |parent, i|
    parent2 = i.even? ? selected[i-1] : selected[i+1]
    parent2 = selected[0] if i == selected.size-1
    #child = crossover(parent, parent2, 0.98, num_periods, num_venues)
    child = copy_timetable(parent, num_periods, num_venues)
    mutate!(child, mutation_swaps, num_periods, num_venues, num_classes, num_teachers)
    child[:fitness] = fitness(child, num_periods, num_venues)
    children << (child[:fitness] < parent[:fitness] ? child : parent)
  end
  return children
end

def new_meeting(klass, teacher, venue)
  { class: klass, teacher: teacher, venue: venue }
end

def generate_requirements_list(requirements, num_teachers, num_classes, num_venues)
  requirements_list = []
  for v in 0...num_venues
    for i in 0...num_classes
      for j in 0...num_teachers
        row = v * num_classes + i
        meetings_per_week = requirements[row][j]
        meetings_per_week.times do
          requirements_list << new_meeting(i, j, v)
        end
      end
    end
  end
  return requirements_list
end

# A timetable is an individual of the population
# Example:
#
# class:
#        venues
# periods 4 1
#         3 4
#         3 2
#         4 2
#
# teacher:
#        venues
# periods 2 1
#         4 3
#         4 3
#         3 2
def new_timetable(num_periods, num_venues)
  {
    class: Array.new(num_periods) { [-1] * num_venues },  # generate an available timetable
    teacher: Array.new(num_periods) { [-1] * num_venues }
  }
end

def clash_free_period?(timetable, num_venues, period, meeting)
  for venue in 0...num_venues
    if venue != meeting[:venue] &&
      (timetable[:class  ][period][venue] == meeting[:class] ||
       timetable[:teacher][period][venue] == meeting[:teacher])
      return false
    end
  end
  return true
end

# The saturation degree is the number of timetable periods
# that the tuple can be allocated to without causing a clash
def calculate_saturation_degree!(timetable, meetings, num_periods, num_venues)
  meetings.each do |meeting|

    saturation_degree = 0
    for period in 0...num_periods
      if clash_free_period?(timetable, num_venues, period, meeting)
        saturation_degree += 1
      end
    end

    meeting[:saturation_degree] = saturation_degree
  end
end

def first_clash_free_period(timetable, meeting, num_periods, num_venues)
  period = 0
  found = false
  while period < num_periods && !found
    if timetable[:class][period][meeting[:venue]] == -1 &&
      clash_free_period?(timetable, num_venues, period, meeting)
      found = true
    else
      period += 1
    end
  end

  if period >= num_periods
    period = -1
  end

  return period
end

def allocate(timetable, period, meeting)
  venue = meeting[:venue]
  timetable[:class][period][venue]   = meeting[:class]
  timetable[:teacher][period][venue] = meeting[:teacher]
end

def random_period(timetable, meeting, num_periods)
  periods = []
  for period in 0...num_periods
    if timetable[:class][period][meeting[:venue]] == -1
      periods << period
    end
  end

  periods.sample
end

def sequential_construction_method(meetings, num_periods, num_venues)
  meetings = meetings.dup
  timetable = new_timetable(num_periods, num_venues)
  calculate_saturation_degree!(timetable, meetings, num_periods, num_venues)

  alpha = 0.3
  while !meetings.empty?
    rcl = []
    min, max = meetings.minmax_by {|m| m[:saturation_degree] }
    rcl_limit = max[:saturation_degree] - alpha * (max[:saturation_degree] - min[:saturation_degree])
    #puts "selecting meeting: #{rcl_limit}"
    meetings.each_with_index do |candidate, i|
      rcl << i if candidate[:saturation_degree] >= rcl_limit
    end
    best_meeting = meetings.delete_at(rcl.sample)
    period = first_clash_free_period(timetable, best_meeting, num_periods, num_venues)
    if period == -1
      period = random_period(timetable, best_meeting, num_periods)
    end
    allocate(timetable, period, best_meeting)
    calculate_saturation_degree!(timetable, meetings, num_periods, num_venues)
  end

  timetable
end

def check_num_periods!(meetings, num_periods, num_venues)
  periods_per_venue = [0] * num_venues
  meetings.each {|m| periods_per_venue[m[:venue]] += 1 }
  periods_per_venue.each_with_index do |periods, venue|
    raise "Incorrect number of periods for venue #{venue}: #{periods} informed,
    should be #{num_periods}" if periods != num_periods
  end
end

def fitness(timetable, num_periods, num_venues)
  fit = 0
  for i in 0...num_periods
    for j in 0...num_venues
      klass = timetable[:class][i][j]
      teacher = timetable[:teacher][i][j]
      meeting = new_meeting(klass, teacher, j)
      if !clash_free_period?(timetable, num_venues, i, meeting)
        fit += 1
      end
    end
  end

  fit
end

def feasible?(timetable, num_periods, num_venues)
  fitness(timetable, num_periods, num_venues) == 0
end

def calculate_fitness!(timetables, num_periods, num_venues)
  timetables.each {|timetable| timetable[:fitness] = fitness(timetable, num_periods, num_venues) }
end

def search(requirements, num_teachers, num_classes, num_venues, num_periods,
           max_gens, pop_size, mutation_swaps, scm_size, tournament_size)
  #puts "beginning search..."
  #puts "generate meetings"
  meetings = generate_requirements_list(requirements, num_teachers, num_classes, num_venues)
  #check_num_periods!(meetings, num_periods, num_venues)

  #puts "generate initial population"
  population = []
  alpha = 0.3
  pop_size.times do
    candidates = []
    scm_size.times do
      candidates << sequential_construction_method(meetings, num_periods, num_venues)
    end
    calculate_fitness!(candidates, num_periods, num_venues)

    rcl = []
    min, max = candidates.minmax_by { |timetable| timetable[:fitness] }
    rcl_limit = max[:fitness] - alpha * (max[:fitness] - min[:fitness])
    #puts "inserting in population: #{rcl_limit}"
    candidates.each do |candidate|
      rcl << candidate if candidate[:fitness] <= rcl_limit
    end
    population << rcl.sample
    #puts "generated #{population.size} individuals"
  end

  #puts "beginning generations"
  best = population.sort_by {|timetable| timetable[:fitness] }.first
  max_gens.times do |gen|
    #print "gen: #{gen}/#{max_gens}\r"
    selected = Array.new(pop_size){ tournament_selection(population, tournament_size, num_periods, num_venues)}
    children = reproduce(selected, mutation_swaps, num_periods, num_venues, num_classes, num_teachers)
    children.sort_by! {|timetable| timetable[:fitness] = fitness(timetable, num_periods, num_venues) }
    if children.first[:fitness] < best[:fitness]
      best = children.first
    end
    population = children
    #puts " > gen #{gen}, best: #{best[:fitness]}"
    break if feasible?(best, num_periods, num_venues)
  end
  return best
end

def generate_requirements(num_teachers, num_classes, num_venues, num_periods)
  requirements = []
  num_venues.times do
    venue = Array.new(num_classes) { [0] * num_teachers }
    num_periods.times do
      row = rand(num_classes)
      col = rand(num_teachers)
      venue[row][col] += 1
    end
    requirements += venue
  end
  requirements
end

if __FILE__ == $0
  problem = "testes-new"

  # problem configuration
  num_teachers = 4
  num_classes = 4
  num_venues = 4

  # algorithm configuration
  max_gens = 50
  num_periods = 30
  pop_size = 100
  scm_size = 1
  tournament_size = 10
  mutation_swaps = 10

  #requirements = generate_requirements(num_teachers, num_classes, num_venues, num_periods)
  #File.open('data/requirements.dat', 'w') {|file| file.write(Marshal.dump(requirements)) }
  requirements = nil
  File.open("data/#{problem}/requirements.dat", 'r') {|file| requirements = Marshal.load(file.read) }
  # execute the algorithm
  10.times do |i|
    #srand i
    srand rand(999)
    best = nil
    bm = Benchmark.measure do
      best = search(requirements, num_teachers, num_classes, num_venues, num_periods,
                    max_gens, pop_size, mutation_swaps, scm_size, tournament_size)
    end
    File.open("results/pop_#{pop_size}/#{problem}/result_#{i}.txt", "w") do |file|
      file.write("fitness: #{best[:fitness]}\n")
      file.write(bm)
      file.write('\n')
    end
  end
  #puts "done! Solution: fitness = #{best[:fitness]}"
  #print_tt best
end
