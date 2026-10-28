require 'tsv'

def return_footway_in_steglitz
  TSV.parse_file("data/steglitz-zehlendorf.tsv", header: false).each do |row|
    next unless row[0] == 'footway'
    puts "#{row[2]}\t#{row[3]}"
  end
  return 0
end

return_footway_in_steglitz();
