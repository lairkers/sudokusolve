# Like in chess the cells are named:
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
      possible_guesses = g.last.map { |num| { :cells => [g.first], :number => num } }

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

  def init_statements
    (1..9).each do |number|
      # Rows
      (1..9).each do |row|
        cells = %w[A B C D E F G H I].map { |c| "#{c}#{row}"}
        @statements << { :cells => cells, :number => number }
      end
      # Columns
      %w[A B C D E F G H I].each do |column|
        cells = %w[1 2 3 4 5 6 7 8 9].map { |r| "#{column}#{r}"}
        @statements << { :cells => cells, :number => number }
      end
      # Blocks
      [%w[A B C], %w[D E F], %w[G H I]].each do |rows|
        [[1, 2, 3], [4, 5, 6], [7, 8, 9]].each do |columns|
          cells = []
          rows.each do |row|
            columns.each do |column|
              cells << "#{row}#{column}"
            end
          end
          @statements << { :cells => cells, :number => number }
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
        @statements << { :cells => ["#{column}#{row}"], :number => number }
      end
    end
  end

  def field
    field = (1..9).map { |row| %w[A B C D E F G H I].map { |col| "#{col}#{row}"}}
                  .flatten
                  .map { |f| [f, @statements.select { |s| s[:cells].include?(f) }.map { |s| s[:number] }.uniq]}
    # TODO: nicer representation as hash instead of first/last
    return field
  end

  def field_as_array
    map = Array.new(9){Array.new(9)}
    statements = @statements.select { |s| s[:cells].size == 1 }
    statements.each do |statement|
      cell = statement[:cells].first
      column_index = %w[A B C D E F G H I].find_index(cell.chars.first)
      row_index = cell.chars.last.to_i - 1
      raise "Found duplicate in #{statement[:cells].first}: Current #{map[row_index][column_index]}, new #{statement[:number]}" unless map[row_index][column_index] == nil
      map[row_index][column_index] = statement[:number]
    end
    return map
  end

  def field_str
    return field_as_array.map { |row| row.map { |c| c.nil? ? ' ' : c }.join }
  end

  def complete?
    return field_str.none? { |s| s.include?(' ') }
  end

  def correct?
    f = field_as_array
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

  def statement_hash
    return @statements.map { |s| s[:cells] }.flatten.size
  end

  def solve_linear
    while true
      while true
        fingerprint = statement_hash
        reduce_statements_by_containment
        reduce_statements_by_single_numbers
        break if fingerprint == statement_hash

        raise "Linear steps lead to invalid solution." unless correct?
      end

      fingerprint = statement_hash
      #reduce_statements_by_closed_groups
      break if fingerprint == statement_hash
    end
  end

  def reduce_statements_by_containment
    @statements.each do |needle|
      # In case any of the steps below already marked this needle as to be deleted
      next if needle[:cells].empty?

      # Contained means: needle has same number and cells is included in statement's cells
      contained_statements = @statements.select { |s| s[:number] == needle[:number] }
                                        .select { |s| needle[:cells].all? { |f| s[:cells].include?(f) } }
                                        .reject { |s| s == needle }

      # 0. If unique: Delete the cell from all other @statements' cells
      if needle[:cells].size == 1
        @statements.select { |s| s[:cells].include?(needle[:cells].first) }
                    .reject { |s| s == needle }
                    .each { |s| s[:cells].reject! { |f| f == needle[:cells].first } }
      end

      # If needle is contained in a statement:
      next if contained_statements.empty?

      # 1. For this number, remove all cells in other statements
      contained_statements.each do |cs|
        cells_to_remove = cs[:cells].reject { |f| needle[:cells].include?(f) }
        @statements.select { |s| s[:number] == cs[:number] }
                   .reject { |s| s == cs }
                   .reject { |s| s == needle }
                   .reject { |s| s[:cells].size == 1 }
                   .each { |s|
                      s[:cells].reject! { |f| cells_to_remove.include?(f) }
                }
      end

      # 2. Mark the whole contained_statement to be deleted
      contained_statements.each { |cs| cs[:cells] = [] }
    end

    # Clean up all statements that are empty after the previous step
    @statements.reject! { |s| s[:cells].empty? }
    @statements.uniq!
  end

  def reduce_statements_by_single_numbers
    # Find single numbers per cell
    single_number_per_cells = []
    @statements.each do |needle|
      needle[:cells].each do |cell|
        next if @statements.any? { |s| s[:cells].include?(cell) && s[:number] != needle[:number] }
        
        single_number_per_cells << { :cells => [cell], :number => needle[:number] }
      end
    end
    @statements.concat(single_number_per_cells)
    @statements.uniq!
  end

  # WIP
  def reduce_statements_by_closed_groups
    # Closed group handling
    groups = []
    @statements.each do |statement|
      group = @statements.select{ |s| s[:cells] == statement[:cells] }
      next if group.nil? || group.size <= 1 || group.map { |s| s[:number] }.uniq.size != group[0][:cells].size

      groups << { :cells => group[0][:cells], :numbers => group.map{ |g| g[:number]} }
    end
    puts("GROUPS")
    groups.uniq!
    groups.each do |group|
      puts('group')
      puts(group)
    end
    groups.each do |group|
      cells_to_remove = group[:cells]
      group[:numbers].each do |number|
        @statements.select { |s| s[:number] == number }
                   .reject { |s| s[:cells] == group[:cells] }
                   .each { |s|
                     puts "Removing #{cells_to_remove} because of group #{group} from #{s}"
                     s[:cells].reject! { |f| cells_to_remove.include?(f) }
                }
      end
    end

    # Clean up all statements that are empty after the previous step
    @statements.reject! { |s| s[:cells].empty? }
    @statements.uniq!
  end

end