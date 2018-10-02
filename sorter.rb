require 'csv'

######################################################
#Intro

=begin

This script reads application data from sorter.csv and
uses a genetic algorithm to aid the Charlotte 
Teacher’s Institute in their admissions process.

The program begins by creating a single random solution
it then creates a number of variants of that solution.

It selects the most fit member of the family it's 
created and uses that as the seed for the next 
generation.

=end


######################################################
#Control variables

#Sets how long the program runs for and how many 
#variants for each generation

$generations = 200
$family_size = 1000

#Show applicant names in the final output

$show_names = true

#Set the desired number for new applicants per seminar. They rest of a seminar's applicants will be people who have already been in the program in past years.

$target_num_new_users_per_seminar = 7

#Set desired numbers of elementary, middle, and high school teacher desired per seminar 

$target_elm_teachers_per_seminar = 4
$target_mid_teachers_per_seminar = 4
$target_hs_teachers_per_seminar = 5

######################################################
# School Bonuses

#Allows the script to prefer applicants from selected schools
#This feature was never fully implemented or used.

$teir_1_school_bouns = 5.0
$teir_2_school_bouns = 1.2
$teir_3_school_bouns = 1.1

$school_bouns = Hash.new(1.0)
######################################################
#User ids who must be admitted

#Allows the script to prefer certain applicants
#This feature was never fully implemented or used

$user_admit = Hash.new(0.0)

######################################################
#functions

#Returns true if an applicant has never been in the program
def new_user?(seminar,user)
  user = $app_ids[seminar][user].to_s
  user[0] == 48
end

#Calculate the fitness score for a seminar
def score_seminar(seminar, members)
  result = 0.0
  
  #Sum up scores for each member
  for m in members
    value = $scores[seminar][m]
    if value != -1000
      value = (value[0].to_f.abs * $school_bouns[$user_school_number[m]]) + $user_admit[m]
    end
    result = result + value
  end
  
  #Prevents Adjustments from going negative in case all application are not rated
  if result < 0.0
    result = 1.0
  end
  
  #Adjust for number of schools in seminar
  schools = Hash.new()
  for m in members
    schools[$user_school[m]] = "found"
  end
  result = result * (1.0 + schools.length/100.0)
  
  #Count up school levels
  num_elm = 0
  num_mid = 0
  num_hs = 0
  for m in members
  		grades = $grades[m]
  		if grades[0] == 49 or grades[1] == 49 or grades[2] == 49 or grades[3] == 49 or grades[4] == 49 or grades[5] == 49 or grades[6] == 49
  			num_elm += 1
  		end
  		if grades[6] == 49 or grades[7] == 49 or grades[8] == 49
  			num_mid += 1
  		end
  		if grades[9] == 49 or grades[10] == 49 or grades[11] == 49 or grades[12] == 49
  			num_hs += 1
  		end
  	end
  	
  	#School Level Bonuses
  	if num_elm == $target_elm_teachers_per_seminar
  		result = result * 1.1
  	elsif (num_elm == $target_elm_teachers_per_seminar + 1) or (num_elm == $target_elm_teachers_per_seminar - 1)
  		result = result * 1.05
  	end
  	if num_mid == $target_mid_teachers_per_seminar
  		result = result * 1.1
  	elsif (num_mid == $target_mid_teachers_per_seminar + 1) or (num_mid == $target_mid_teachers_per_seminar - 1)
  		result = result * 1.05
  	end
  	if num_hs == $target_hs_teachers_per_seminar
  		result = result * 1.1
  	elsif (num_hs == $target_hs_teachers_per_seminar + 1) or (num_hs == $target_hs_teachers_per_seminar - 1)
  		result = result * 1.05
  	end
  
  
  #Adjust for number of grade levels in seminar
=begin
  key = "0000000000000"
  for m in members
    grades = $grades[m]
    for x in (0..12)
      if grades[x] == 49
			key[x] = '1'
      end
    end
  end
  num_grades = 0
  for x in (0..12)
    if key[x] == 49
      num_grades += 1
    end
  end
  result = result * (1.0 + num_grades/100.0)
=end
  
  #Adjust for ratio of new to returning applicants
  new_users = 0
  for m in members
    if new_user?(seminar,m)
      new_users += 1
    end
  end
  target = $target_num_new_users_per_seminar
  if new_users == target
    result *= 1.06
  elsif (new_users == target +1) or (new_users == target -1)
    result *= 1.05
  elsif (new_users == target +2) or (new_users == target -2)
    result *= 1.04
  elsif (new_users == target +3) or (new_users == target -3)
    result *= 1.03
  elsif (new_users == target +4) or (new_users == target -4)
    result *= 1.02
  elsif (new_users == target +5) or (new_users == target -5)
    result *= 1.01
  end
  
  #Adjust for number of members in a seminar where the max is 13
  size = members.length
  if size <= 13
    result = result * (1.1 ** size)
  else
    result = -100000.0
  end
  
  result
end

#return true if you should not put that user into that seminar
def bad_match(seminar, user)
   $scores[seminar][user] == -1000
end

#Returns a random user
def get_random_user
  $user_keys.sample()
end

def get_random_seminar
  $seminar_keys.sample()
end

def deep_copy(o)
  Marshal.load(Marshal.dump(o))
end

def print_solution(solution)
  total_score = 0.0
  for s in $seminar_keys
    print s.to_s + ": " 
    for i in solution[s]
      print i.to_s + " "
    end
    score = score_seminar(s, solution[s])
    total_score = total_score + score
    print " Score: "+ score.to_s + "\n"
  end
  print "unused users: "
  for u in solution["unused"]
    print u.to_s + " "
  end
  print "\nTotal Score : " + total_score.to_s + "\n"
  print "--------------------------------------------\n"
end

def print_grades(user)
  grades = $grades[user]
  print grades[0,6]
  print "-"
  print grades[6,3]
  print "-"
  print grades[9,4]
end

def other_seminar_choices(exclude,user)
  result = []
  for seminar in $seminar_keys
    if (seminar != exclude) and ( !bad_match(seminar, user) )
      app_id = $app_ids[seminar][user].to_s.reverse
      choice = app_id[0,1]
      review = $avg_review[seminar][user].to_f    
      if review >= 0.0
	result << "[" + seminar.to_s + choice + " " + '%.2f' % review + "] "
      else
	result << "[" + seminar.to_s + choice + " NR] "
      end
    end
  end
  result
end

def all_seminar_choices(user)
  other_seminar_choices(0,user)
end

def num_past_seminars(user)
  for seminar in $seminar_keys
    if $app_ids[seminar][user] != "no app"
      return $app_ids[seminar][user][0,1]
    end
  end
end

def print_final_solution(solution)
  total_score = 0.0
  print "--------------------------------------------\n"
  print "-------- STARTING SOLUTION -----------------\n"
  print "--------------------------------------------\n\n"
  for s in $seminar_keys
    print $seminars[s].to_s + " (" + s + ")\n"
    slot = 1
    for i in solution[s].sort! { |a,b| $avg_review[s][b] <=> $avg_review[s][a] }
      printf("    #%-3d ", slot.to_s);
      if $avg_review[s][i].to_s != "-0.001"
	printf("%-.2f  ", $avg_review[s][i].to_s)
      else
	printf("NR    ")
      end
      printf("%-8s  ", $app_ids[s][i].to_s)
      if $show_names
	name = $users[i].to_s
	printf("%-20s ", name[0,20])
      end
      printf("%-2d  ", $years_teaching[i])
      print_grades(i)
      school = $user_school[i].to_s
      printf("  %-15s  ",school[0,15])
      for choice in other_seminar_choices(s,i)
	print choice
      end
      #printf("            %s" ,$user_teaches[i]) 
      print"\n"
      slot += 1
    end    
    score = score_seminar(s, solution[s])
    total_score = total_score + score
    print "\n"
  end
  print "-------------------------------------------------------------------------------------------------------\n\n"
  print "NOT POPULATED:\n"
  for u in solution["unused"].sort!  { |a,b| a.to_i <=> b.to_i }
    print "    "
    printf("%-4d", u.to_s)
    if $show_names
      name = $users[u].to_s
      printf(" %-20s ", name[0,20])
      printf(" %-3s ", num_past_seminars(u))
      printf("%-2d  ", $years_teaching[u])
      print_grades(u)
      school = $user_school[u].to_s
      printf("  %-15s  ",school[0,15])
      for choice in all_seminar_choices(u)
	print choice
      end
    end
    print "\n"
  end
  print "\nTotal Score : " + total_score.to_s + "\n"
  print "--------------------------------------------\n"
end

######################################################
#read csv data into useful structures

infile = CSV.read("./sorter.csv")
# Format: 
# App_ID, Score, Grades, User, User-Name, School, Seminar, Seminar-Title, School-Name, Courses Taught, Average Reviewer Score, Years-teaching
# 0       1      2       3     4          5       6        7              8            9              10                       11
# 2.86a,  1.1,   010000, 86,   "Edwards,",25,     39,      American Pol,  Bailey Mid,  "History, S",  4.0,                     26

#Initialize Structures
num_apps = 0
$users = Hash.new('BAD USER')
$grades = Hash.new([])
$seminars = Hash.new('not entered')
$scores = Hash.new('not a seminar')
$schools = Hash.new()
$user_school = Hash.new()
$user_school_number = Hash.new()
$app_ids = Hash.new('not a seminar')
$user_teaches = Hash.new()
$avg_review = Hash.new()
$years_teaching = Hash.new()

scoresFile = File.new("./scores.txt", "w")

for i in infile
  
  num_apps = num_apps + 1
  
  #Stores user's names
  $users[i[3]] = i[4]
  
  #Stores user's grades
  $grades[i[3]] = i[2]
  
  #Stores Seminar's names
  $seminars[i[6]] = i[7]
  
  #Stores Scores indexed by Seminar, Users
  if !$scores.has_key?(i[6])
    $scores[i[6]] = Hash.new(-1000.0)
  end
  $scores[i[6]][i[3]] = [i[1]]
  #scoresFile.syswrite(i[6].to_s + ", " + i[3].to_s + ", " +i[1].to_s + "\n"	)
  
  #Stores App-IDs indexed by Seminar, Users
  if !$app_ids.has_key?(i[6])
    $app_ids[i[6]] = Hash.new("no app")
  end
  $app_ids[i[6]][i[3]] = i[0]
  
  $schools[i[8]] = i[8] 
  
  $user_school[i[3]] = i[8]
  $user_school_number[i[3]] = i[5]
  
  $user_teaches[i[3]] = i[9]
  
  #Stores Average Review Score by Seminar, User
  if !$avg_review.has_key?(i[6])
    $avg_review[i[6]] = Hash.new(-1000.0)
  end
  $avg_review[i[6]][i[3]] = i[10]
  
  #Stores Years Teaching
  $years_teaching[i[3]] = i[11]
  
end
scoresFile.close

$num_schools = $schools.length
$seminar_keys = $seminars.keys.sort!
$seminars_count = $seminar_keys.length
$user_keys = $users.keys

print "Read " + $users.length.to_s + " Users. \n"
print "Read " + $seminars.length.to_s + " Seminars. \n"
print "Read " + num_apps.to_s + " Applications. \n"
print "Read " + $num_schools.to_s + " Schools. \n"


######################################################
# Generating first solution

parent = Hash.new()
for s in $seminar_keys
  parent[s] = []
  parent["unused"] = $user_keys 
end

for s in $seminar_keys
  target = rand(2)+2
  for x in (1..target)
    user_pos = rand(parent["unused"].length - 1)
      #Get a user that actually can apply to seminar s
      while bad_match(s,parent["unused"][user_pos])
	user_pos = rand(parent["unused"].length - 1)
      end
    parent[s] << parent["unused"].delete_at(user_pos)
  end
end

#print "Generation #p"
#print_solution(parent)
#print_final_solution(parent)

######################################################
# Generating family

#Main loops for generations
for gen in (0..$generations)
  
  printf("Generation %s",gen.to_s)
  
  #Family creation
  family = []
  family_scores = []
  for size in (0..$family_size)
    child = deep_copy(parent)
    #print_solution(child)
    
    #sometimes do more than one mutation per child
    rnum = rand()
    mutations = 1
    if rnum < 0.5
      mutations = 2
    end
    if rnum < 0.4
      mutations = 3
    end
    if rnum < 0.3
      mutations = 4
    end
    if rnum < 0.2
      mutations = 5
    end
    if rnum < 0.1
      mutations = 6
    end
    
    #Creates a wide variety of solutions on first generation
    if gen == 0
      mutations = 500
    end
    
    for x in (0..mutations)
    
      user = get_random_user()
      
      #If this user is in the unused group all we need to do is add it to a seminar  
      if child["unused"].include?(user)
	seminar = get_random_seminar
	#Get a user that actually can apply to seminar s
	while bad_match(seminar,user)
	  seminar = get_random_seminar
	end
	child[seminar] << child["unused"].delete(user)
      
      else #If this user is in a seminar we need to remove them and add a random unused user to a random seminar
      
	#print "Used user:" + user + "\n"
	#Remove the user and add to unused group
	for s in $seminar_keys
	  child[s].delete(user)
	end
	child["unused"] << user
      
	#Add random unsued user to random seminar
	seminar = get_random_seminar
	user = child["unused"][rand(child["unused"].length)]
	while bad_match(seminar,user)
	  seminar = get_random_seminar
	  user = child["unused"][rand(child["unused"].length)]
	end
	child[seminar] << child["unused"].delete(user)
      
      end #if
      
      #If any of the seminars in the child solution have more than 15 members randomly remove a user
      for s in $seminar_keys
	if child[s].size > 13
	  #print "Trimming\n"
	  child["unused"] << child[s].delete(child[s].sample)
	end
      end
      
    end #done creating child solution
	
    
    family << deep_copy(child)
      
    #score the solution
    score = 0.0
    for s in $seminar_keys
      score = score + score_seminar(s, family[size][s])
    end
    family_scores << score
      
  end #End family creation
  
  #Clone the parrent too incase none of the children are better
  family << deep_copy(parent)
  score = 0.0
  for s in $seminar_keys
    score = score + score_seminar(s, parent[s])
  end
  family_scores << score
  
  #find top scoring child and make them the parent
  index = 0
  top_score_pos = 0
  top_score = -10000.0
  for score in family_scores
      if score > top_score
	top_score = score
	top_score_pos = index
      end
      index = index + 1
  end
      
  #Report Generational result 
  print " Top Score: " + top_score.to_s + "\n"
  
  #Replace parent with top scoring child
  parent = deep_copy(family[top_score_pos])
      
end #End main loop for generations
print "\n\n"
print_final_solution(parent)

#Print all users with their coruses
print "-------------------------------------------------------------------------------------------------------\n\n"
print "TEACHING NEXT YEAR:\n\n"
  
for key in $user_keys.sort! { |a,b| $users[a].downcase <=> $users[b].downcase }
  printf("%-20s  %s\n", $users[key][0,20], $user_teaches[key])
end
