Then(/^I should see the name of the device used for testing$/) do
  expect(page).to have_css('#info-sections .device-info .device-name', text: 'iPhone 8')
end

Then(/^I should see the iOS version of the device used for testing$/) do
  expect(page).to have_css('#info-sections .device-info .device-os', text: 'iOS 11.2')
end

Then(/^I should see the model of the device used for testing$/) do
  expect(page).to have_css('#info-sections .device-info .device-model', text: 'Model: iPhone 8')
end

Then(/^I should see the identifier of the device used for testing$/) do
  pry
  expect(page).to have_css('#info-sections .device-info .device-identifier', text: 'Identifier: 7FF91090-3F5B-4DC2-AA5B-D6DC12B6F9EF')
end
