When(/^I click on the link to the activity logs$/) do
  find('header #test-log-toolbar li', :text => 'Logs').click
end

Then(/^I should see the activity logs$/) do
  expect(page).to have_selector('#main-content .run #logs', :count => 1)
end
