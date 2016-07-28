require 'nokogiri'

# This class is response for parsing HTML into scores and calculating GPA
class Score
  attr_reader :score_list, :gpas

  def initialize
    @score_file = 'temp/credit_score.html'
    @guide_score_file = 'temp/guide_score.html'
    @credit_list = []
    @guide_score_list = []
    @gpas = []
    @score_list = []
    calc_gpa
  end

  def update?(last_score)
    last_name = last_score.last.map { |s| s[:name] }
    current_name = @score_list.last.map { |s| s[:name] }
    (current_name & last_name) != current_name
  end

  private

    def calc_gpa(only_required = true)
      init_score
      # Only compute required course by default
      @score_list.each do |s|
        sum = s.inject([0,0]) do |temp, c|
          next temp if c[:prop] == '选修' && only_required
          [temp.first + c[:point] * c[:credit], temp.last + c[:credit]]
        end
        @gpas << {
          credit: sum.last,
          # Avoid 0 / 0 (Maybe only optional courses occur in this semester)
          gpa: (sum.last.zero? ? 0 : (sum.first / sum.last)).round(3)
        }
      end
    end

    def init_score
      parse_score
      parse_credit # Get credit list of courses
      merge_by_name # Merge by course's name
      nest_with_date # Store into an 2D Array based on different semesters
    end

    def calc_point(grade)
      # only numbers and dots
      res = ((grade.to_i - 60) / 5) * 0.5 + 2.0
      return 0 if res < 2
      return 5.0 if res > 5
      res
    end

    # rubocop:disable Metrics/AbcSize
    def parse_score
      page = Nokogiri::HTML(open(@guide_score_file).read, nil, 'gbk')
      subjects = page.css('tr.odd')
      subjects.each do |m|
        next unless m.children[9] && m.children[9].text.strip.length == 8
        vals = [1, 3, 7, 9].map { |i| m.children[i].text.slice(1..-1).strip }
        vals << calc_point(vals[2])
        keys = [:cno, :name, :grade, :date, :point]
        @guide_score_list << Hash[keys.zip vals]
      end
    end

    def parse_credit
      page = Nokogiri::HTML(open(@score_file).read, nil, 'gbk')
      subjects = page.css('tr.odd')
      subjects.each do |m|
        vals = [5, 7, 9, 11].map { |i| m.children[i].text.strip }
        vals[2] = vals[2].to_f
        keys = [:name, :eng_name, :credit, :prop]
        @credit_list << Hash[keys.zip vals]
      end
    end

    def merge_by_name
      @guide_score_list.each do |g|
        @credit_list.each do |s|
          # Merge two hashes if courses' names are same.
          g.merge! s if g[:name] == s[:name]
        end
      end
    end

    def nest_with_date
      res = []
      z = 0
      second_semester = 500...1100
      flag = false
      @guide_score_list.each do |s|
        z += 1
        # The flag is true when second and false when first semester.
        # Change semester when flag changed.
        date = s[:date].slice(-4..-1).to_i
        res << (z - 1) unless flag == second_semester.include?(date)
        flag = second_semester.include?(date)
      end
      res << z
      res.length.times do |i|
        # Divide scores based on semester
        @score_list << @guide_score_list.slice((i.zero? ? 0 : res[i - 1])...res[i])
      end
    end
end
