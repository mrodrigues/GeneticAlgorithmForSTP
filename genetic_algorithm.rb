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

def tournament_selection(population, tournment_size)
  winner = population.sample

  (1...tournment_size).each do
    current = population.sample
    current = population.sample while current == winner

    if (rand(3) % 3 == 0)
      if current[:fitness] < winner[:fitness]
        winner = current
      end
    elsif (rand(3) % 3 == 1)
      winner = current
    # else winner is not changed 
    end
  end

  return winner
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

def mutate!(timetable, s_mutations, num_periods, num_venues, num_classes, num_teachers)
  s_mutations.times do |i|
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
            swap(first_clash, second_clash)
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

def crossover(parent1, parent2, rate)
  return ""+parent1 if rand()>=rate
  point = 1 + rand(parent1.size-2)
  return parent1[0...point]+parent2[point...(parent1.size)]
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

def reproduce(selected, s_mutations, num_periods, num_venues, num_classes, num_teachers)
  children = []
  selected.each_with_index do |parent, i|
    child = copy_timetable(parent, num_periods, num_venues)
    mutate!(child, s_mutations, num_periods, num_venues, num_classes, num_teachers)
    child[:fitness] = fitness(child, num_periods, num_venues)
    children << (child[:fitness] < parent[:fitness] ? child : parent)
    #break if children.size >= pop_size
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

  while !meetings.empty?
    meetings.sort! {|r1, r2| r2[:saturation_degree] <=> r1[:saturation_degree] }
    best_meeting = meetings.shift
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

def search(requirements, num_teachers, num_classes, num_venues, num_periods,
           max_gens, pop_size, s_mutations, scm_size, tournament_size)
  meetings = generate_requirements_list(requirements, num_teachers, num_classes, num_venues)
  check_num_periods!(meetings, num_periods, num_venues)

  population = []
  pop_size.times do
    candidates = []
    scm_size.times do
      candidates << sequential_construction_method(meetings, num_periods, num_venues)
    end
    candidates.sort_by! {|timetable| timetable[:fitness] = fitness(timetable, num_periods, num_venues) }
    population << candidates.first
  end

  best = population.sort_by {|timetable| timetable[:fitness] }.first
  max_gens.times do |gen|
    selected = Array.new(pop_size){|i| tournament_selection(population, tournament_size)}
    children = reproduce(selected, s_mutations, num_periods, num_venues, num_classes, num_teachers)
    children.sort_by! {|timetable| timetable[:fitness] = fitness(timetable, num_periods, num_venues) }
    if children.first[:fitness] < best[:fitness]
      puts "change best"
      best = children.first
    end
    population = children
    #puts " > gen #{gen}, best: #{best[:fitness]}"
    break if feasible?(best, num_periods, num_venues)
  end
  return best
end

if __FILE__ == $0
  # problem configuration
  requirements = [
    # venue 0
    [0,1,1],
    [2,0,2],

    # venue 1
    [0,0,0],
    [0,3,3]
  ]
  num_teachers = 3
  num_classes = 2
  num_venues = 2

  # algorithm configuration
  max_gens = 200
  num_periods = 6
  pop_size = 50
  scm_size = 10
  tournament_size = 10
  #p_crossover = 0.90
  num_mutations_tries = 10
  # execute the algorithm
  best = search(requirements, num_teachers, num_classes, num_venues, num_periods,
                max_gens, pop_size, num_mutations_tries, scm_size, tournament_size)
  puts "done! Solution: f=#{best[:fitness]}"
  print_tt best
end
