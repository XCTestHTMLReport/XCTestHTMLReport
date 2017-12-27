Given(/^the (.*) test is unfolded$/) do |n|
  step "I click on the #{n} test"
  step "I hit the right arrow key"
  step "I should see the activities of the #{n} test"
end

When(/^I click on the (.*) test$/) do |n|
  index = 1 if n == 'first'
  index = 2 if n == 'second'

  find(".summary .test-summary-group .test-summary-group .test-summary-group:nth-of-type(1) .test-summary:nth-of-type(#{index})").click
end

When(/^I hit the (.*) arrow key$/) do |direction|
  key = :arrow_up if direction == 'up'
  key = :arrow_right if direction == 'right'
  key = :arrow_down if direction == 'down'
  key = :arrow_left if direction == 'left'

  find('body').send_keys key
end

Then(/^I should( not)? see the activities of the (.*) test$/) do |negate, n|
  index = 1 if n == 'first'
  index = 2 if n == 'second'

  count = negate ? 0 : 1

  expect(page).to have_selector(".summary .test-summary-group .test-summary-group .test-summary-group:nth-of-type(1) .test-summary:nth-of-type(#{index}) .activities", :count => count)
end

Then(/^the (.*) test should be selected$/) do |n|
  index = 1 if n == 'first'
  index = 2 if n == 'second'

  expect(page).to have_selector(".summary .test-summary-group .test-summary-group .test-summary-group:nth-of-type(1) .test-summary:nth-of-type(#{index}).selected", :count => 1)
end
