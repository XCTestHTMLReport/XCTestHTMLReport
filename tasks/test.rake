desc 'Runs the acceptance tests'
task :test  do
  puts "Running Tests"
  system "cucumber"
end
