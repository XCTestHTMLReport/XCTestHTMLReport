Given(/^the (.*) test is unfolded$/) do |n|
  step "I click on the #{n} test"
  step "I hit the right arrow key"
  step "I should see the activities of the #{n} test"
end

When(/^I click on the (.*) test$/) do |n|
  index = 0 if n == 'first'
  index = 1 if n == 'second'

  all(".summary .test-summary")[index].click
end

When(/^I hit the (.*) arrow key$/) do |direction|
  key = :arrow_up if direction == 'up'
  key = :arrow_right if direction == 'right'
  key = :arrow_down if direction == 'down'
  key = :arrow_left if direction == 'left'

  find('body').send_keys key
end

Then(/^I should( not)? see the activities of the (.*) test$/) do |negate, n|
  index = 0 if n == 'first'
  index = 1 if n == 'second'

  test_summary = all('.summary .test-summary')[index]

  visible = negate ? false : true

  expect(test_summary).to have_selector('.activities', :visible => visible)
end

Then(/^the (.*) test should be selected$/) do |n|
  index = 0 if n == 'first'
  index = 1 if n == 'second'

  test_summary = all('.summary .test-summary')[index]

  expect(test_summary).to have_selector('.selected')
end
