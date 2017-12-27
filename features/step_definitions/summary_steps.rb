Then(/^I should see the test summary$/) do
  expect(page).to have_css('.summary .test-summary-group', :text => 'All tests - 5 tests')
  expect(page).to have_css('.summary .test-summary-group .test-summary-group', :text => 'XCUITestHTMLReportSampleAppUITests.xctest')
  expect(page).to have_css('.summary .test-summary-group .test-summary-group .test-summary-group', :text => 'FirstSuite - 3 tests')
  expect(page).to have_css('.summary .test-summary-group .test-summary-group .test-summary-group .test-summary', :text => 'testHTMLAttachement()')
  expect(page).to have_css('.summary .test-summary-group .test-summary-group .test-summary-group .test-summary', :text => 'testTextAttachement()')
  expect(page).to have_css('.summary .test-summary-group .test-summary-group .test-summary-group .test-summary', :text => 'testWithoutAttachement()')

  expect(page).to have_css('.summary .test-summary-group .test-summary-group .test-summary-group', :text => 'SecondSuite - 2 tests')
  expect(page).to have_css('.summary .test-summary-group .test-summary-group .test-summary-group .test-summary', :text => 'testWithoutAttachementOne()')
  expect(page).to have_css('.summary .test-summary-group .test-summary-group .test-summary-group .test-summary', :text => 'testWithoutAttachementTwo()')
end
