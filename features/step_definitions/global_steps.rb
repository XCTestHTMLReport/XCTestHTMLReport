Given(/^I have opened the report$/) do
  path = 'file://' + Dir.pwd + '/TestResults/index.html'
  visit(path)
  expect(page).to have_css('body.loaded')
end

When(/^I click on the "(.*)" link$/) do |text|
  find('a', :text => text).click
end

Then(/^I should be on "(.*)"$/) do |link|
  expect(page).to have_current_path(link)
end
