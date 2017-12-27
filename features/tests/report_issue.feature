Feature: Report an issue

Scenario: As a user, I should be able to report an issue
    Given I have opened the report
     When I click on the "Report an issue" link
     Then I should be on "https://github.com/TitouanVanBelle/XCUITestHTMLReport/blob/master/CONTRIBUTING.md#reporting-issues"
