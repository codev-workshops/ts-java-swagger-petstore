@store @address
Feature: Add a store address (POST /store/address)
  As an API client
  I want to add a new address to the store
  So that it can later be fetched, updated and deleted by its id

  Background:
    Given the petstore API is running

  @happy-path
  Scenario: Add a new store address with a JSON body
    When I send a POST request to "/store/address" with body:
      """
      {
        "id": 101,
        "street": "1 Main St",
        "city": "Springfield",
        "state": "IL",
        "zipCode": "62701",
        "country": "USA"
      }
      """
    Then the response status should be 200
    And the response content type should be "application/json"
    And the response body should be a valid Address
    And the response body should be an Address with:
      | id      | 101         |
      | street  | 1 Main St   |
      | city    | Springfield |
      | state   | IL          |
      | zipCode | 62701       |
      | country | USA         |
    And a GET request to "/store/address/101" should return status 200

  @happy-path @xml
  Scenario: Add a new store address with an XML body and receive XML back
    Given I accept "application/xml" responses
    When I send a POST request to "/store/address" with XML body:
      """
      <address>
        <id>102</id>
        <street>10 Downing St</street>
        <city>London</city>
        <state>England</state>
        <zipCode>SW1A 2AA</zipCode>
        <country>UK</country>
      </address>
      """
    Then the response status should be 200
    And the response content type should be "application/xml"
    And the response body should be XML with root element "Address"

  @schema
  Scenario: Adding an address that already exists replaces it
    Given a store address exists with id 103
    When I send a POST request to "/store/address" with body:
      """
      {"id": 103, "street": "2 Second Ave", "city": "Denver", "state": "CO", "zipCode": "80202", "country": "USA"}
      """
    Then the response status should be 200
    And the response body should be an Address with:
      | id     | 103          |
      | street | 2 Second Ave |
      | city   | Denver       |

  @validation @error-400
  Scenario: Adding an address without a request body is rejected as invalid input
    When I send a POST request to "/store/address"
    Then the response status should be 400
    And the response body should not be empty

  @validation @error-400
  Scenario: Adding an address with an empty request body is rejected as invalid input
    When I send a POST request to "/store/address" with an empty body
    Then the response status should be 400

  @validation @error-400
  Scenario Outline: Adding an address whose body does not match the Address schema is rejected
    When I send a POST request to "/store/address" with body:
      """
      <body>
      """
    Then the response status should be 400

    Examples:
      | body                                          |
      | {"id": "not-a-number", "street": "1 Main St"} |
      | ["not", "an", "object"]                       |
      | this is not json                              |
