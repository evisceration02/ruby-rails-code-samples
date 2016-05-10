class Category < ActiveRecord::Base
	has_and_belongs_to_many :questions
	validates :name, presence: true

	default_scope { order('name ASC') }

	def self.reassign(name, target_name)
		c = where(name: name).first
		target_c = where(name: target_name).first
		raise "Category not found" unless c && target_c
		c.questions.each do |question|
			question.categories.destroy(c)
			question.categories << target_c
		end
		c.destroy
	end

	def self.names
		all.map(&:name)
	end

	def ordered_questions
		questions.includes(section: :test).sort_by do |question|
			[question.test.rank, question.section.num]
		end
	end

	def serialize_questions
		Test.where(test_type: test_type).includes(sections: :questions).map do |test|
			{
				title: test.title,
				sections: test.sections.inject([]) do |memo, section|
					section_questions = questions.where(section: section)
					if section_questions.present?
						memo.push({
							num: section.num,
							questions: section_questions.map do |question|
								src_paths = get_paths(test, section, question)
								{
									num: question.num,
									answer: question.answer,
									notes: question.notes,
									reference_path: src_paths[:reference_path],
									img_path: src_paths[:img_path]
								}
							end
						})
					end
					memo
				end
			}
		end
	end

	def get_paths(test, section, question)
		dir = Rails.root.join("app", "assets", "images", "screenshots", test.title, "section_#{section.num}")
		question_filename = Dir.entries(dir).detect { |filename| filename =~ /q#{question.num}.png$/ || filename =~ /q#{question.num}.jpg$/ }
		# raise "Question file not found" if question_filename.nil?
		if question_filename.nil?
			return {
				:reference_path => nil,
				:img_path => nil
			}
		end
		filename_pieces = question_filename.split("_q")
		reference = filename_pieces.length > 1 ? filename_pieces.first : nil
		reference_filename = reference ? Dir.entries(dir).detect { |filename| filename =~ /#{reference}.png$/ || filename =~ /#{reference}.jpg$/ } : nil
		question_filenames = reference ? Dir.entries(dir).select { |filename| filename =~ /#{reference}_/ }.sort_by do |name|
			name.split('_q').last.split('.').first.to_i
		end : [question_filename]
		{
			img_path: question_filenames.map { |name| File.join("/assets", "screenshots", test.title, "section_#{section.num}", name) },
			reference_path: reference_filename ? File.join("/assets", "screenshots", test.title, "section_#{section.num}", reference_filename) : nil
		}
	end


end
