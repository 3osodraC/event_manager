require 'csv'
require 'date'
require 'erb'
require 'google/apis/civicinfo_v2'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

# Cleans phone numbers by;
# 1. Removing any non-numerical characters.
# 2. Checking if number is valid, returns 'Unavailable' if unvalid.
# 3. Formatting number to (000)000-0000 template.
def clean_phone_number(phone_number)
  phone_number = phone_number.gsub(/[^\d]/, '')

  case
  when phone_number.size == 11 && phone_number[0] == '1'
    phone_number.delete_prefix('1')
    phone_number
  when phone_number.size < 10 || phone_number.size > 11
    'Unavailable'
  when phone_number.size == 11 && phone_number[0] != '1'
    'Unavailable'
  else
    phone_number
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

# Returns registration hour
def find_reg_hour(reg_date)
  time_format = "%m/%d/%y %H:%M"
  time = DateTime.strptime(reg_date, time_format)
  time.hour
end

# Returns registration weekday
def find_reg_wday(reg_date)
  time_format = "%m/%d/%y %H:%M"
  time = DateTime.strptime(reg_date, time_format)
  time.wday
end

# Returns most frequent number in array, used for finding peak days/hours
def most_frequent(arr)
  reg_counts = arr.tally
  reg_counts.max_by { |n, count| count }.first
end

def save_thank_you_letter(id, form_letter)
  FileUtils.mkdir_p('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.html')
erb_template = ERB.new template_letter

# Arrays for all registration hours and weekdays
reg_hour_arr = []
reg_wday_arr = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  reg_hour_arr.push(find_reg_hour(row[:regdate]))
  reg_wday_arr.push(find_reg_wday(row[:regdate]))

  zipcode = clean_zipcode(row[:zipcode])

  phone_number = clean_phone_number(row[:homephone])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
  puts phone_number
end

puts "Peak Hour (24h format): #{most_frequent(reg_hour_arr)}"
puts "Peak Weekday (Sun = 0 - Sat = 6): #{most_frequent(reg_wday_arr)}"
