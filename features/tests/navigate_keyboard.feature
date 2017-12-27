Feature: Navigate - Keyboard

Scenario: As a user, I want to be able to unfold a test with the right arrow key
    Given I have opened the report
     When I click on the first test
      And I hit the right arrow key
     Then I should see the activities of the first test

Scenario: As a user, I want to be able to fold a test with the left arrow key
    Given I have opened the report
      And the first test is unfolded
     When I hit the left arrow key
     Then I should not see the activities of the first test

Scenario: As a user, I want to be able to move to the next test with the down arrow key
    Given I have opened the report
     When I click on the first test
      And I hit the down arrow key
     Then the second test should be selected

Scenario: As a user, I want to be able to move to the previous test with the up arrow key
    Given I have opened the report
     When I click on the second test
      And I hit the up arrow key
      Then the first test should be selected
