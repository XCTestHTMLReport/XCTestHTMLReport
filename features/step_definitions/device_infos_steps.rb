Then(/^I should see the name of the device used for testing$/) do
  expect(page).to have_css('#info-sections .device-info .device-name', text: 'iPhone 8', count: 1)
  expect(page).to have_css('#info-sections .device-info .device-name', text: 'iPhone X', count: 1)
  expect(page).to have_css('#info-sections .device-info .device-name', text: 'iPhone 7', count: 1)
end

Then(/^I should see the iOS version of the device used for testing$/) do
  expect(page).to have_css('#info-sections .device-info .device-os', text: 'iOS 11.2', count: 3)
end

Then(/^I should see the model of the device used for testing$/) do
  expect(page).to have_css('#info-sections .device-info .device-model', text: 'Model: iPhone 8', count: 1)
  expect(page).to have_css('#info-sections .device-info .device-model', text: 'Model: iPhone X', count: 1)
  expect(page).to have_css('#info-sections .device-info .device-model', text: 'Model: iPhone 7', count: 1)
end

Then(/^I should see the identifier of the device used for testing$/) do
  expect(page).to have_css('#info-sections .device-info .device-identifier', text: 'Identifier: 7FF91090-3F5B-4DC2-AA5B-D6DC12B6F9EF', count: 1)
  expect(page).to have_css('#info-sections .device-info .device-identifier', text: 'Identifier: 0C421F44-D1A5-4374-AEDF-98497C8599DB', count: 1)
  expect(page).to have_css('#info-sections .device-info .device-identifier', text: 'Identifier: F961AF76-1840-4E07-8B2B-9020E5AC69FC', count: 1)
end
