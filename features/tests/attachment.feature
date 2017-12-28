Feature: Attachamenet

Scenario: As a user, I should be able to see image attachements
    Given I have opened the report
     When I click on an image attachement
     Then I should see the image attachement

Scenario: As a user, I should be able to see text attachements
    Given I have opened the report
     When I click on a text attachement
     Then I should see the text attachement

Scenario: As a user, I should be able to see HTML attachements
    Given I have opened the report
     When I click on an HTML attachement
     Then I should see the HTML attachement
