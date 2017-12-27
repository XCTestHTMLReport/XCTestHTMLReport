Feature: Filtering

Scenario: As a user, I can filter out all the tests which failed
    Given I have opened the report
     When I filter out the tests which failed
     Then I should only see the tests which succeeded

Scenario: As a user, I can filter out all the tests which succeeded
    Given I have opened the report
     When I filter out the tests which succeeded
     Then I should only see the tests which failed

Scenario: As a user, I can remove the filter
    Given I have opened the report
      And I have filtered out the tests which succeeded
     When I remove the filter
     Then I should see all the tests which failed and which succeeded
