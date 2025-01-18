#!/usr/bin/ruby

require_relative 'solver'

def success?(result, expected)
  result.first(9).each { |l| l.strip }.join(',') == expected.first(9).each { |l| l.strip }.join(',')
end

def test(input_file, expected_file)
  puts "Testing #{input_file}"
  result = Solver.solve(filename: input_file)
  expected = File.readlines(expected_file, chomp: true)
  success = false
  if result.size == 1
    success = success?(result.first, expected)
  else
    success = false
    result.each do |solution|
      puts "----------"
      puts solution
      s = success?(solution, expected)
      puts "NICE" if s
      success |= s
    end
  end
  puts "SUCCESS" if success
  puts "FAILURE" unless success
end

if __FILE__ == $PROGRAM_NAME
  test('test/test1', 'test/expected1')
  test('test/test2', 'test/expected2')
end