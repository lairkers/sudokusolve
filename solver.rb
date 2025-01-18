# Like in chess the fields are named:
#   A B C D E F G H I
# 1
# 2
# ..
# 9

class Solver
  attr_reader :solutions

  def self.solve(filename: '', statements: nil, depth: 0)
    s = Solver.new(filename: filename, statements: statements, depth: depth)
    s.run
    return s.solutions
  end

  def initialize(filename: '', statements: nil, depth: 0)
    raise "Depth too high: #{depth}" if depth >= 5
    @depth = depth
    @solutions = []
    unless filename.empty?
      @statements = []
      init_statements
      read_statements_from_file(filename)
    else
      @statements = statements
    end
  end

  def run
    start_time = Time.now

    solve_linear

    if complete?
      @solutions << field_str
    else
      possibilities = field.reject { |p| p.last.size == 1 }
      lowest_num_of_possibilities = possibilities.map { |p| p.last.size }.min
      g = possibilities.find { |p| p.last.size == lowest_num_of_possibilities }
      possible_guesses = g.last.map { |num| { :fields => [g.first], :number => num } }

      #puts('Intermediate result')
      #puts(field_str)
      #puts('Intermediate statements')
      #puts(@statements)
      #puts('possible guesses')
      #puts(possible_guesses)

      possible_guesses.each do |guess|
        puts "#{' ' * @depth}Depth #{@depth}: Guessing #{guess}"
        begin
          statements = Marshal.load(Marshal.dump(@statements))
          statements << guess
          @solutions.concat(Solver.solve(statements: statements, depth: @depth + 1))
        rescue
          puts "#{' ' * @depth}Depth #{@depth}: -> invalid"
        end
      end
    end

    stop_time = Time.now
    puts "#{' ' * @depth}Depth #{@depth}: Took #{((stop_time - start_time) * 1000).round} ms"
  end

  private

  def field
    field = (1..9).map { |row| %w[A B C D E F G H I].map { |col| "#{col}#{row}"}}
                  .flatten
                  .map { |f| [f, @statements.select { |s| s[:fields].include?(f) }.map { |s| s[:number] }.uniq]}
    # TODO: nicer representation as hash instead of first/last
    return field
  end

  def field_array
    map = Array.new(9){Array.new(9)}
    statements = @statements.select { |s| s[:fields].size == 1 }
    statements.each do |statement|
      field = statement[:fields].first
      column_index = %w[A B C D E F G H I].find_index(field.chars.first)
      row_index = field.chars.last.to_i - 1
      raise "Found duplicate in #{statement[:fields].first}: Current #{map[row_index][column_index]}, new #{statement[:number]}" unless map[row_index][column_index] == nil
      map[row_index][column_index] = statement[:number]
    end
    return map
  end

  def field_str
    return field_array.map { |row| row.map { |c| c.nil? ? ' ' : c }.join }
  end

  def complete?
    return field_str.none? { |s| s.include?(' ') }
  end

  def correct?
    f = field_array
    # Rows
    (0..8).each do |row|
      (1..9).each do |number|
        return false if 1 < (0..8).count { |column| f[row][column] == number }
      end
    end
    # Columns
    (0..8).each do |column|
      (1..9).each do |number|
        return false if 1 < (0..8).count { |row| f[row][column] == number }
      end
    end
    # Blocks
    [[0, 1, 2], [3, 4, 5], [6, 7, 8]].each do |rows|
      [[0, 1, 2], [3, 4, 5], [6, 7, 8]].each do |columns|
        (1..9).each do |number|
          return false if 1 < rows.sum { |row| n = columns.count { |column| f[row][column] == number }}
        end
      end
    end
    return true
  end

  def init_statements
    (1..9).each do |number|
      # Rows
      (1..9).each do |row|
        fields = %w[A B C D E F G H I].map { |c| "#{c}#{row}"}
        @statements << { :fields => fields, :number => number }
      end
      # Columns
      %w[A B C D E F G H I].each do |column|
        fields = %w[1 2 3 4 5 6 7 8 9].map { |r| "#{column}#{r}"}
        @statements << { :fields => fields, :number => number }
      end
      # Blocks
      [%w[A B C], %w[D E F], %w[G H I]].each do |rows|
        [[1, 2, 3], [4, 5, 6], [7, 8, 9]].each do |columns|
          fields = []
          rows.each do |row|
            columns.each do |column|
              fields << "#{row}#{column}"
            end
          end
          @statements << { :fields => fields, :number => number }
        end
      end
    end
  end

  def read_statements_from_file(filename)
    File.readlines(filename, chomp: true).each_with_index do |line, row_minus_one|
      line.chars.first(9).each_with_index do |number_as_str, column_as_int|
        next if number_as_str == ' '
        number = number_as_str.to_i
        column = %w[A B C D E F G H I][column_as_int]
        row = row_minus_one + 1
        @statements << { :fields => ["#{column}#{row}"], :number => number }
      end
    end
  end

  def solve_linear
    num_statements = @statements.map { |s| s[:fields] }.flatten.size + 1
    while num_statements > @statements.map { |s| s[:fields] }.flatten.size
      num_statements = @statements.map { |s| s[:fields] }.flatten.size
      linear_step
    end
  end

  def linear_step
    @statements.each do |needle|
      # In case any of the steps below already marked this needle as to be deleted
      next if needle[:fields].empty?

      # Contained means: needle has same number and fields is included in statement's fields
      contained_statements = @statements.select { |s| s[:number] == needle[:number] }
                                        .select { |s| needle[:fields].all? { |f| s[:fields].include?(f) } }
                                        .reject { |s| s == needle }

      if needle[:fields].size == 1
        # 2. If unique: Delete the field from all other @statements' fields
        @statements.select { |s| s[:fields].include?(needle[:fields].first) }
                    .reject { |s| s == needle }
                    .each { |s| s[:fields].reject! { |f| f == needle[:fields].first } }
      end

      # If needle is contained in a statement:
      next if contained_statements.empty?

      # 0. For this number, remove all fields in other statements
      contained_statements.each do |cs|
        fields_to_remove = cs[:fields].reject { |f| needle[:fields].include?(f) }
        @statements.select { |s| s[:number] == cs[:number] }
                   .reject { |s| s == cs }
                   .reject { |s| s == needle }
                   .reject { |s| s[:fields].size == 1 }
                   .each { |s|
                      s[:fields].reject! { |f| fields_to_remove.include?(f) }
                }
      end

      # 1. Mark the whole contained_statement to be deleted
      contained_statements.each { |cs| cs[:fields] = [] }
    end

    # Clean up all statements that are empty after the previous step
    @statements.reject! { |s| s[:fields].empty? }
    @statements.uniq!

    # Find single numbers per field
    single_number_per_fields = []
    @statements.each do |needle|
      needle[:fields].each do |field|
        next if @statements.any? { |s| s[:fields].include?(field) && s[:number] != needle[:number] }
        
        single_number_per_fields << { :fields => [field], :number => needle[:number] }
      end
    end
    @statements.concat(single_number_per_fields)
    @statements.uniq!

    raise "Linear steps lead to invalid solution." unless correct?
  end

end