Then(/^I should see the test summary$/) do
  device_count = all('#info-sections .device-info').count

  expect(page).to have_css('.run', :count => device_count, :visible => :all)
  expect(page).to have_css('.run.active', :count => 1, :visible => true)
  expect(page).to have_css('.run', :visible => :hidden, :count => device_count - 1)
end
