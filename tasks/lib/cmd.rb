# frozen_string_literal: true

require_relative './print'

# Class for Cmd
class Cmd
  attr_reader :cmd

  def initialize(cmd)
    @cmd = cmd
  end

  def run(error_message: 'Failed to execute command.')
    error_message += " Cmd: #{@cmd}"

    Print.step 'Running ' + @cmd

    success = system @cmd
    Print.error error_message unless success
    exit 1 unless success
  end
end
