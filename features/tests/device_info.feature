Feature: Device Info

Scenario: As a user, I should see the information related to the device used to run the tests
    Given I have opened the report
     Then I should see the name of the device used for testing
     Then I should see the iOS version of the device used for testing
     Then I should see the model of the device used for testing
     Then I should see the identifier of the device used for testing
