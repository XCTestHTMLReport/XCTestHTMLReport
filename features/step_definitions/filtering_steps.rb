Given(/^I have filtered out the tests which succeeded$/) do
  step 'I filter out the tests which succeeded'
end

When(/^I filter out the tests which failed$/) do
  find('#main-content .run .tests-header .toggle-toolbar li', :text => 'Passed').click
end

When(/^I filter out the tests which succeeded$/) do
  find('#main-content .run .tests-header .toggle-toolbar li', :text => 'Failed').click
end

When(/^I remove the filter$/) do
  find('#main-content .run .tests-header .toggle-toolbar li', :text => 'All').click
end

Then(/^I should only see the tests which succeeded$/) do
  expect(page).to have_selector('.test-summary.list-item', :count => 2)
end

Then(/^I should only see the tests which failed$/) do
  expect(page).to have_selector('.test-summary.list-item', :count => 3)
end

Then(/^I should see all the tests which failed and which succeeded$/) do
  expect(page).to have_selector('.test-summary.list-item', :count => 5)
end
