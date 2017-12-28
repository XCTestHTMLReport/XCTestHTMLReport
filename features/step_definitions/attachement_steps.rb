When(/^I click on an image attachement$/) do
  test_summary = first('.test-summary', :text => 'testWithImageAttachement()')
  test_summary.find('.drop-down-icon').click

  image_attachement = test_summary.find('.activity', :text => 'Image Attachment')
  image_attachement.find('.drop-down-icon').click

  image_attachement.find('.attachment').click
end

Then(/^I should see the image attachement$/) do
  test_summary = first('.test-summary', :text => 'testWithImageAttachement()')
  image_attachement = test_summary.find('.activity', :text => 'Image Attachment')
  image_to_load = image_attachement.find('.screenshot', :visible => false)
  loaded_image = find('#right-sidebar img')

  expect(loaded_image['src']).to have_content image_to_load['src']
end

When(/^I click on a text attachement$/) do
  pending # Write code here that turns the phrase above into concrete actions
end

Then(/^I should see the text attachement$/) do
  pending # Write code here that turns the phrase above into concrete actions
end

When(/^I click on an HTML attachement$/) do
  pending # Write code here that turns the phrase above into concrete actions
end

Then(/^I should see the HTML attachement$/) do
  pending # Write code here that turns the phrase above into concrete actions
end

When(/^I click on a crash report attachement$/) do
  pending # Write code here that turns the phrase above into concrete actions
end

Then(/^I should see the crash report attachement$/) do
  pending # Write code here that turns the phrase above into concrete actions
end
