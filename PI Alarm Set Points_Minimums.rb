#This program works to establish Low, LoLo, Low, and LoLo alarm set points. This is achieved
#by first flagging flat-lined or stale data points and then computing a Z-score table. Based
#on a Z-score acceptance factor, individual data points are included/excluded. Minimum and 
#minimum values are then extracted from remaining data points.

require 'csv'			#Include CSV parsing library.
require 'green_shoes'	#Include graphics library.
print "Parsing... \n"

LOW_FACTOR = 1.0
LOLO_FACTOR = 0.9


#*********************************************************************************************
#*								 Determine if string is numeric.							 *
#*********************************************************************************************
class String
	def valid_float?
		true if Float self rescue false
	end
end


#*********************************************************************************************
#*								Determine is data point is valid.							 *
#*********************************************************************************************
def is_invalid?(num_1, num_2, num_3)
	flatlined = false

	if num_2 == num_1 || num_2 == num_3 || num_2.to_f.nan? || num_2 == 0 || !num_2.valid_float?
		flatlined = true
	end

	return flatlined
end


#*********************************************************************************************
#*							Establish custom ceiling/floor functions.						 *
#*********************************************************************************************
class Float
	def ceil_to(x)
		x = 1 / x
		(self * x).ceil.to_f / x
	end

	def floor_to(x)
		x = 1 / x
		(self * x).floor.to_f / x
	end
end


#*********************************************************************************************
#*			       			Establish LoLo and Low alarm set points.				    	 *
#*********************************************************************************************
temp_SUM = 0
temp_LEN = 0
short_AVG = 0
long_AVG = 0
temp_AVG = 0
temp_MID = 0
temp_VAR = 0
temp_STD = 0
temp_MIN = 0
temp_LOW = 0
temp_LOLO = 0
temp_COUNT = 0
temp_arr = Array.new
short_arr = Array.new
long_arr = Array.new
temp_arr_holding = Array.new
alarm_arr = Array.new
#alarm_arr = ["PI Tag:", "Average:", "Minimum:", "LoLo:", "Low:"]
k = 0

data_acceptange_percentage = 25	#Define percentage of raw data to use.
z_acceptance = 4.0	#Define Z-Score acceptance threshold	


#*********************************Parse CSV files into RAM************************************
temp_file = ask_open_file("")
min_arr = CSV.read(temp_file)

#min_arr = CSV.read("min.csv")


#******************************Identify statistical minimum***********************************
min_arr.each do |min_row|
	
	temp_SUM = 0
	temp_LEN = 0
	temp_MID = 0
	temp_VAR = 0
	short_arr.clear

	for i in (min_row.length * (data_acceptange_percentage / 100)) - 2..min_row.length - 2 do	#Filter flat-lined and NaN data.
		if !is_invalid?(min_row[i - 1], min_row[i], min_row[i + 1]) 
			temp_SUM = temp_SUM + min_row[i].to_f
			temp_LEN += 1
			short_arr << min_row[i].to_f
		end
	end
	short_AVG = (temp_SUM / temp_LEN).to_f rescue short_AVG = 0	#Calculate short-term average.


	temp_SUM = 0
	temp_LEN = 0
	temp_MID = 0
	temp_VAR = 0
	long_arr.clear

	for i in 1..min_row.length - 2 do	#Filter flat-lined and NaN data.
		if !is_invalid?(min_row[i - 1], min_row[i], min_row[i + 1]) 
			temp_SUM = temp_SUM + min_row[i].to_f
			temp_LEN += 1
			long_arr << min_row[i].to_f
		end
	end
	long_AVG = (temp_SUM / temp_LEN).to_f rescue long_AVG = 0	#Calculate long-term average.

	temp_arr.clear	

	if short_AVG * 1.1 < long_AVG	#Determine if there has been an operational shift in the short-term.
		temp_AVG = short_AVG
		temp_arr << short_arr
	else
		temp_AVG = long_AVG
		temp_arr << long_arr.flatten
	end
	temp_arr.flatten!


	temp_arr.each do |temp_value|	#Calculate variance.
		temp_VAR = temp_VAR + (temp_value - temp_AVG) ** 2
	end
	temp_VAR = temp_VAR / temp_LEN rescue temp_VAR = 0 
	temp_STD = Math.sqrt(temp_VAR)	#Calculate standard deviation.

	temp_arr.sort!{ |x, y| y <=> x }
	
	temp_MID = (temp_arr[temp_arr.length - 1] - temp_arr[0]) / 2 rescue temp_MID = 0
	for i in 0..temp_arr.length - 1 do
		temp_Z = (temp_arr[i] - temp_AVG).abs / temp_STD #rescue temp_Z = 0
		if temp_Z <= z_acceptance
			temp_arr_holding << temp_arr[i]
		end
	end

	temp_arr = temp_arr_holding

	temp_arr.pop

	temp_AVG = temp_arr.inject(:+) / temp_arr.length rescue temp_AVG = 0

	temp_LOW = 0	#Initialize variable.
	temp_LOLO = 0	#Initialize variable.

	temp_MIN = temp_arr.last rescue temp_MIN = 0	#Extract minimum array value.
	unless temp_MIN.nil? || temp_arr.length <= 1	#temp_MIN == 0
		if temp_MIN.abs <= 0.5
			temp_LOW = (temp_MIN - (temp_MIN * (1 - LOW_FACTOR)).abs).floor_to(0.05)
			temp_LOLO = (temp_MIN - (temp_MIN * (1 - LOLO_FACTOR)).abs).floor_to(0.05)
			while temp_LOW == temp_LOLO
				temp_LOLO = (temp_LOLO - 0.05).floor_to(0.05)
			end
		elsif temp_MIN.abs <= 1
			temp_LOW = (temp_MIN - (temp_MIN * (1 - LOW_FACTOR)).abs).floor_to(0.25)
			temp_LOLO = (temp_MIN - (temp_MIN * (1 - LOLO_FACTOR)).abs).floor_to(0.25)
			while temp_LOW == temp_LOLO
				temp_LOLO = (temp_LOLO - 0.25).floor_to(0.25)
			end
		elsif temp_MIN.abs <= 5
			temp_LOW = (temp_MIN - (temp_MIN * (1 - LOW_FACTOR)).abs).floor_to(0.5)
			temp_LOLO = (temp_MIN - (temp_MIN * (1 - LOLO_FACTOR)).abs).floor_to(0.5)
			while temp_LOW == temp_LOLO
				temp_LOLO = (temp_LOLO - 0.5).floor_to(0.5)
			end
		elsif temp_MIN.abs <= 25
			temp_LOW = (temp_MIN - (temp_MIN * (1 - LOW_FACTOR)).abs).floor_to(1.0)
			temp_LOLO = (temp_MIN - (temp_MIN * (1 - LOLO_FACTOR)).abs).floor_to(1.0)
			while temp_LOW == temp_LOLO
				temp_LOLO = (temp_LOLO - 1.0).floor_to(1.0)
			end
		elsif temp_MIN.abs <= 50
			temp_LOW = (temp_MIN - (temp_MIN * (1 - LOW_FACTOR)).abs).floor_to(2.0)
			temp_LOLO = (temp_MIN - (temp_MIN * (1 - LOLO_FACTOR)).abs).floor_to(2.0)
			while temp_LOW == temp_LOLO
				temp_LOLO = (temp_LOLO - 2.0).floor_to(2.0)
			end
		elsif temp_MIN.abs <= 250
			temp_LOW = (temp_MIN - (temp_MIN * (1 - LOW_FACTOR)).abs).floor_to(5.0)
			temp_LOLO = (temp_MIN - (temp_MIN * (1 - LOLO_FACTOR)).abs).floor_to(5.0)
			while temp_LOW == temp_LOLO
				temp_LOLO = (temp_LOLO - 5.0).floor_to(5.0)
			end
		else 
			temp_LOW = (temp_MIN - (temp_MIN * (1 - LOW_FACTOR)).abs).floor_to(10.0)
			temp_LOLO = (temp_MIN - (temp_MIN * (1 - LOLO_FACTOR)).abs).floor_to(10.0)
			while temp_LOW == temp_LOLO
				temp_LOLO = (temp_LOLO - 10.0).floor_to(10.0)
			end
		end
	end

	temp_PI = min_row[0].to_s
	temp_COUNT = min_row.delete_if{|temp| temp.to_f >= 
		temp_LOW.to_f}.length

	alarm_arr << [temp_PI, temp_AVG, temp_arr.last, 
		temp_LOLO, temp_LOW, temp_COUNT]

end

alarm_arr.unshift(["PI Tag:", "Average:", "Minimum:", "LoLo:", "Low:", "Count:"])	#Append headers.

File.open(temp_file[0...-4] + "_OUT.csv", 'w'){|csv| csv << alarm_arr.map(&:to_csv).join}