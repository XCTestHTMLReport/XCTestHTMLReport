# frozen_string_literal: true

require 'colorize'

# Class for the Logger
module Print
  module_function

  def debug(log)
    puts log.to_s
  end

  def print_separator
    puts '---'
  end

  def step(log)
    partition = log.to_s.partition ' '
    word_in_bold = partition.shift

    puts '▸ '.green + word_in_bold.bold + partition.join
  end

  def error(log)
    puts '❌ ' + log.to_s.red
  end

  def warning(log)
    puts '⚠️ Warning: ' + log.to_s.yellow
  end

  def success(log)
    puts '✅ ' + log.to_s.green.bold
  end

  def info(log)
    puts "\n" + log.to_s.bold + "\n\n"
  end
end
