require 'csv'

# parses exam data in a csv into db records
# csv cell order: question_num, section_num, answer, categories
# invoked by import.rake
class Importer

	def dir
		@dir ||= Rails.root.join('datafiles')
	end

	def import(test_type)
	  Dir.foreach(dir) do |file_name|
      if file_name =~ /.csv/
        test_name = file_name.split(".").first
        if Test.where(title: test_name).empty?
          test = create_test(test_name, test_type)
          create_questions(file_name, test, test_type)
        end
      end
    end
  end

  def create_test(test_name, test_type)
    rank = test_name.last.to_i
  	Test.where(title: test_name, test_type: test_type).first || Test.create!(title: test_name, rank: rank, test_type: test_type)
  end

  def create_questions(file_name, test, test_type)
  	CSV.foreach("#{dir}/#{file_name}") do |row|
      category_names = row.drop(3).compact
      categories = category_names.map do |name|
        Category.where(name: name, test_type: test_type).first || Category.create!(name: name, test_type: test_type)
      end
      section = test.sections.where(num: row[1]).first || test.sections.create!(num: row[1])
      unless Question.where(num: row[0], answer: row[2], section: section).first
        q = Question.create!(num: row[0], answer: row[2], section: section)
        q.categories << categories
      end
  	end
  end
end