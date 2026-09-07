@store @address
Feature: Manage a store address by id (/store/address/{addressId})
  As an API client
  I want to fetch, update and delete a store address by its id
  So that I can maintain the store's addresses

  Background:
    Given the petstore API is running

  # ---------------------------------------------------------------------------
  # GET /store/address/{addressId}
  # ---------------------------------------------------------------------------

  @get @happy-path
  Scenario: Find an existing store address by id
    Given a store address exists with id 201
    When I send a GET request to "/store/address/201"
    Then the response status should be 200
    And the response content type should be "application/json"
    And the response body should be a valid Address
    And the response body should be an Address with:
      | id      | 201        |
      | street  | 437 Lytton |
      | city    | Palo Alto  |
      | state   | CA         |
      | zipCode | 94301      |
      | country | USA        |

  @get @happy-path @xml
  Scenario: Find an existing store address by id as XML
    Given a store address exists with id 202
    And I accept "application/xml" responses
    When I send a GET request to "/store/address/202"
    Then the response status should be 200
    And the response content type should be "application/xml"
    And the response body should be XML with root element "Address"

  @get @error-404
  Scenario: Finding a store address that does not exist returns 404
    Given no store address exists with id 299
    When I send a GET request to "/store/address/299"
    Then the response status should be 404
    And the response body should be "Address not found"

  @get @validation @error-400
  Scenario Outline: Finding a store address with an invalid id returns 400
    When I send a GET request to "/store/address/<addressId>"
    Then the response status should be 400

    Examples:
      | addressId |
      | abc       |
      | 1.5       |
      | 12x       |

  # ---------------------------------------------------------------------------
  # PUT /store/address/{addressId}
  # ---------------------------------------------------------------------------

  @put @happy-path
  Scenario: Update an existing store address
    Given a store address exists with id 301
    When I send a PUT request to "/store/address/301" with body:
      """
      {
        "id": 301,
        "street": "500 Market St",
        "city": "San Francisco",
        "state": "CA",
        "zipCode": "94105",
        "country": "USA"
      }
      """
    Then the response status should be 200
    And the response content type should be "application/json"
    And the response body should be a valid Address
    And the response body should be an Address with:
      | id      | 301           |
      | street  | 500 Market St |
      | city    | San Francisco |
      | zipCode | 94105         |
    When I send a GET request to "/store/address/301"
    Then the response status should be 200
    And the response body should be an Address with:
      | street | 500 Market St |
      | city   | San Francisco |

  @put @schema
  Scenario: The path addressId takes precedence over the id in the request body
    Given a store address exists with id 302
    When I send a PUT request to "/store/address/302" with body:
      """
      {"id": 999999, "street": "1 Elm St", "city": "Boston", "state": "MA", "zipCode": "02108", "country": "USA"}
      """
    Then the response status should be 200
    And the response body should be an Address with:
      | id     | 302      |
      | street | 1 Elm St |

  @put @happy-path @xml
  Scenario: Update an existing store address with an XML body
    Given a store address exists with id 303
    And I accept "application/xml" responses
    When I send a PUT request to "/store/address/303" with XML body:
      """
      <address>
        <id>303</id>
        <street>221B Baker St</street>
        <city>London</city>
        <state>England</state>
        <zipCode>NW1 6XE</zipCode>
        <country>UK</country>
      </address>
      """
    Then the response status should be 200
    And the response content type should be "application/xml"
    And the response body should be XML with root element "Address"

  @put @error-404
  Scenario: Updating a store address that does not exist returns 404
    Given no store address exists with id 399
    When I send a PUT request to "/store/address/399" with body:
      """
      {"id": 399, "street": "Nowhere", "city": "Nowhere", "state": "NA", "zipCode": "00000", "country": "NA"}
      """
    Then the response status should be 404
    And the response body should be "Address not found"

  @put @validation @error-400
  Scenario: Updating a store address with an invalid id returns 400
    When I send a PUT request to "/store/address/abc" with body:
      """
      {"id": 1, "street": "437 Lytton", "city": "Palo Alto", "state": "CA", "zipCode": "94301", "country": "USA"}
      """
    Then the response status should be 400

  @put @validation @error-400
  Scenario: Updating a store address without a request body returns 400
    Given a store address exists with id 304
    When I send a PUT request to "/store/address/304"
    Then the response status should be 400

  @put @validation @error-400
  Scenario: Updating a store address with a body that does not match the Address schema returns 400
    Given a store address exists with id 305
    When I send a PUT request to "/store/address/305" with body:
      """
      {"id": "not-a-number"}
      """
    Then the response status should be 400

  # ---------------------------------------------------------------------------
  # DELETE /store/address/{addressId}
  # ---------------------------------------------------------------------------

  @delete @happy-path
  Scenario: Delete an existing store address
    Given a store address exists with id 401
    When I send a DELETE request to "/store/address/401"
    Then the response status should be 200
    And the response body should be "Address deleted"
    And a GET request to "/store/address/401" should return status 404

  @delete @error-404
  Scenario: Deleting a store address that does not exist returns 404
    Given no store address exists with id 499
    When I send a DELETE request to "/store/address/499"
    Then the response status should be 404
    And the response body should be "Address not found"

  @delete @validation @error-400
  Scenario Outline: Deleting a store address with an invalid id returns 400
    When I send a DELETE request to "/store/address/<addressId>"
    Then the response status should be 400

    Examples:
      | addressId |
      | abc       |
      | 1.5       |
