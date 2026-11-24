@store
Feature: Store resource
  As a Petstore API client
  I want to check inventory and place, look up and cancel orders
  So that customers can purchase pets

  Endpoints covered (src/main/resources/openapi.yaml, tag "store"):
    GET    /store/inventory          getInventory   api_key (header "api_key")
    POST   /store/order              placeOrder     no security requirement
    GET    /store/order/{orderId}    getOrderById   no security requirement
    DELETE /store/order/{orderId}    deleteOrder    no security requirement

  Spec notes used for boundary scenarios:
    getOrderById: "For valid response try integer IDs with value <= 5 or > 10.
                   Other values will generate exceptions."
    deleteOrder:  "For valid response try integer IDs with value < 1000. Anything
                   above 1000 or non-integers will generate API errors."
  Order endpoints declare no security, so their @auth scenarios verify they stay
  publicly accessible; inventory scenarios assert 401 for a missing/invalid api_key.

  Scenarios tagged @known-gap fail against the current server and are excluded from
  `mvn test`; the @gap-* tag names the missing behavior. Run them with
  -Dcucumber.filter.tags="@known-gap".

  Background:
    Given the Petstore API base URL is "/api/v3"
    And the request header "Accept" is "application/json"

  # ---------------------------------------------------------------------------
  # GET /store/inventory  (getInventory)
  # ---------------------------------------------------------------------------

  @getInventory @positive
  Scenario: Get the pet inventory with a valid api_key
    Given the request header "api_key" is "special-key"
    When I send a GET request to "/store/inventory"
    Then the response status code should be 200
    And the response content type should be "application/json"
    And the response body should be a map of string keys to int32 values

  @getInventory @positive
  Scenario: Inventory reflects a newly placed order's status and quantity
    Given the request header "api_key" is "special-key"
    And I record the inventory count for status "approved"
    And an order with id 7001, status "approved" and quantity 3 exists
    When I send a GET request to "/store/inventory"
    Then the response status code should be 200
    And the inventory count for status "approved" should have increased by 3

  @getInventory @negative
  Scenario Outline: Inventory ignores unexpected query parameters and methods are restricted
    Given the request header "api_key" is "special-key"
    When I send a <method> request to "/store/inventory<query>"
    Then the response status code should be <code>

    Examples:
      | method | query           | code |
      | GET    | ?status=unknown | 200  |
      | POST   |                 | 405  |
      | DELETE |                 | 405  |

  @getInventory @negative
  Scenario: Inventory request with an unsupported Accept header
    Given the request header "api_key" is "special-key"
    And the request header "Accept" is "text/csv"
    When I send a GET request to "/store/inventory"
    Then the response status code should be one of "200,406"

  @getInventory @auth @known-gap @gap-auth
  Scenario: Reject inventory request without an api_key
    Given I am not authenticated
    When I send a GET request to "/store/inventory"
    Then the response status code should be 401

  @getInventory @auth
  Scenario Outline: Reject inventory request with an invalid api_key
    Given the request header "api_key" is "<apiKey>"
    When I send a GET request to "/store/inventory"
    Then the response status code should be 401

    @known-gap @gap-auth
    Examples:
      | description     | apiKey             |
      | wrong key       | not-a-real-key     |
      | empty key       |                    |

  @getInventory @auth @known-gap @gap-auth
  Scenario: Reject inventory request that sends the api_key as a query parameter
    Given I am not authenticated
    When I send a GET request to "/store/inventory?api_key=special-key"
    Then the response status code should be 401

  @getInventory @auth @known-gap @gap-auth
  Scenario: Reject inventory request that uses an OAuth2 token instead of api_key
    Given I am authorized with an OAuth2 bearer token with scopes "write:pets,read:pets"
    When I send a GET request to "/store/inventory"
    Then the response status code should be 401

  @getInventory @boundary
  Scenario: Inventory counts are never negative
    Given the request header "api_key" is "special-key"
    When I send a GET request to "/store/inventory"
    Then the response status code should be 200
    And every value in the response map should be greater than or equal to 0

  @getInventory @boundary
  Scenario: Inventory omits or zeroes a status that no order has
    Given the request header "api_key" is "special-key"
    When I send a GET request to "/store/inventory"
    Then the response status code should be 200
    And the inventory count for status "unknown-status" should be 0 or absent

  # ---------------------------------------------------------------------------
  # POST /store/order  (placeOrder)
  # ---------------------------------------------------------------------------

  @placeOrder @positive
  Scenario: Place a valid order
    Given the request body is:
      """
      {
        "id": 101,
        "petId": 1,
        "quantity": 1,
        "shipDate": "2026-12-01T10:00:00.000Z",
        "status": "placed",
        "complete": false
      }
      """
    When I send a POST request to "/store/order" with content type "application/json"
    Then the response status code should be 200
    And the response body should match the "Order" schema
    And the response field "id" should equal 101
    And the response field "status" should equal "placed"
    When I send a GET request to "/store/order/101"
    Then the response status code should be 200

  @placeOrder @positive
  Scenario Outline: Place an order with each allowed status
    Given the request body is:
      """
      { "id": <id>, "petId": 1, "quantity": 1, "status": "<status>", "complete": <complete> }
      """
    When I send a POST request to "/store/order" with content type "application/json"
    Then the response status code should be 200
    And the response field "status" should equal "<status>"
    And the response field "complete" should equal <complete>

    Examples:
      | id  | status    | complete |
      | 102 | placed    | false    |
      | 103 | approved  | false    |
      | 104 | delivered | true     |

  @placeOrder @positive
  Scenario Outline: Place an order using the "<contentType>" request format
    Given a valid order payload with id 105 and petId 1 encoded as "<contentType>"
    When I send a POST request to "/store/order" with content type "<contentType>"
    Then the response status code should be 200
    And the response field "id" should equal 105

    Examples:
      | contentType                       |
      | application/json                  |
      | application/xml                   |
      | application/x-www-form-urlencoded |

  @placeOrder @negative
  Scenario: Reject an order with an empty request body
    When I send a POST request to "/store/order" with content type "application/json" and no body
    Then the response status code should be 400

  @placeOrder @negative
  Scenario: Reject an order with malformed JSON
    Given the request body is:
      """
      { "id": 106, "petId": 1, "quantity":
      """
    When I send a POST request to "/store/order" with content type "application/json"
    Then the response status code should be 400

  @placeOrder @negative
  Scenario Outline: Reject an order with an invalid field value
    Given the request body is:
      """
      <body>
      """
    When I send a POST request to "/store/order" with content type "application/json"
    Then the response status code should be one of "400,422"

    Examples:
      | description           | body                                                           |
      | id is a string        | { "id": "abc", "petId": 1, "quantity": 1 }                     |
      | petId is a string     | { "id": 108, "petId": "dog", "quantity": 1 }                   |
      | quantity is a string  | { "id": 109, "petId": 1, "quantity": "seven" }                 |
      | shipDate not ISO-8601 | { "id": 110, "petId": 1, "quantity": 1, "shipDate": "tomorrow" } |
      | complete not boolean  | { "id": 111, "petId": 1, "quantity": 1, "complete": "yes" }    |

    @known-gap @gap-input-validation
    Examples: known gaps
      | description           | body                                                           |
      | status not in enum    | { "id": 107, "petId": 1, "quantity": 1, "status": "shipped" }  |

  @placeOrder @negative
  Scenario: Reject an order with an unsupported content type
    Given the request body is "id=112&petId=1"
    When I send a POST request to "/store/order" with content type "text/plain"
    Then the response status code should be 415

  @placeOrder @auth
  Scenario: Place an order without credentials (endpoint is public per spec)
    Given I am not authenticated
    And a valid order payload with id 113 and petId 1 encoded as "application/json"
    When I send a POST request to "/store/order" with content type "application/json"
    Then the response status code should be 200

  @placeOrder @auth
  Scenario: An invalid api_key does not block placing an order
    Given the request header "api_key" is "not-a-real-key"
    And a valid order payload with id 114 and petId 1 encoded as "application/json"
    When I send a POST request to "/store/order" with content type "application/json"
    Then the response status code should be 200

  @placeOrder @boundary
  Scenario Outline: Place an order with boundary quantity values
    Given the request body is:
      """
      { "id": 115, "petId": 1, "quantity": <quantity>, "status": "placed" }
      """
    When I send a POST request to "/store/order" with content type "application/json"
    Then the response status code should be one of "<codes>"

    Examples:
      | description         | quantity    | codes   |
      | zero                | 0           | 200,422 |
      | one                 | 1           | 200     |
      | negative            | -1          | 200,422 |
      | int32 maximum       | 2147483647  | 200     |
      | int32 max overflow  | 2147483648  | 400     |
      | int32 min underflow | -2147483649 | 400     |

    @known-gap @gap-input-validation
    Examples: known gaps
      | description         | quantity    | codes   |
      | decimal             | 1.5         | 400     |

  @placeOrder @boundary
  Scenario Outline: Place an order with boundary id and petId values
    Given the resource at "/store/order/<id>" is deleted after the scenario
    And the request body is:
      """
      { "id": <id>, "petId": <petId>, "quantity": 1, "status": "placed" }
      """
    When I send a POST request to "/store/order" with content type "application/json"
    Then the response status code should be <code>

    Examples:
      | description              | id                  | petId               | code |
      | zero ids                 | 0                   | 0                   | 200  |
      | int64 max ids            | 9223372036854775807 | 9223372036854775807 | 200  |
      | id int64 overflow        | 9223372036854775808 | 1                   | 400  |
      | petId int64 overflow     | 116                 | 9223372036854775808 | 400  |

  @placeOrder @boundary
  Scenario Outline: Place an order with boundary shipDate values
    Given the request body is:
      """
      { "id": 117, "petId": 1, "quantity": 1, "shipDate": "<shipDate>" }
      """
    When I send a POST request to "/store/order" with content type "application/json"
    Then the response status code should be <code>

    Examples:
      | description         | shipDate                  | code |
      | epoch               | 1970-01-01T00:00:00.000Z  | 200  |
      | leap day            | 2028-02-29T00:00:00.000Z  | 200  |
      | far future          | 9999-12-31T23:59:59.999Z  | 200  |

    @known-gap @gap-input-validation
    Examples: known gaps
      | description         | shipDate                  | code |
      | invalid leap day    | 2027-02-29T00:00:00.000Z  | 400  |
      | invalid month       | 2026-13-01T00:00:00.000Z  | 400  |
      | date without time   | 2026-12-01                | 400  |

  @placeOrder @boundary
  Scenario: Place an order with only an empty JSON object
    Given the resource at "/store/order/0" is deleted after the scenario
    And the request body is:
      """
      {}
      """
    When I send a POST request to "/store/order" with content type "application/json"
    Then the response status code should be one of "200,400,422"

  # ---------------------------------------------------------------------------
  # GET /store/order/{orderId}  (getOrderById)
  # ---------------------------------------------------------------------------

  @getOrderById @positive
  Scenario: Get a seeded order by id
    When I send a GET request to "/store/order/1"
    Then the response status code should be 200
    And the response body should match the "Order" schema
    And the response field "id" should equal 1

  @getOrderById @positive
  Scenario Outline: Get an order by id in the "<accept>" format
    Given an order with id 201 and petId 1 exists
    And the request header "Accept" is "<accept>"
    When I send a GET request to "/store/order/201"
    Then the response status code should be 200
    And the response content type should be "<accept>"

    Examples:
      | accept           |
      | application/json |
      | application/xml  |

  @getOrderById @negative
  Scenario: Get an order that does not exist returns 404
    Given no order with id 299 exists
    When I send a GET request to "/store/order/299"
    Then the response status code should be 404
    And the response body should contain "Order not found"

  @getOrderById @negative
  Scenario Outline: Reject a non-integer order id
    When I send a GET request to "/store/order/<orderId>"
    Then the response status code should be 400

    Examples:
      | orderId |
      | abc     |
      | 1.5     |
      | false   |

  @getOrderById @auth
  Scenario: Get an order without credentials (endpoint is public per spec)
    Given I am not authenticated
    When I send a GET request to "/store/order/1"
    Then the response status code should be 200

  @getOrderById @auth
  Scenario: An invalid OAuth2 token does not block looking up an order
    Given I am authorized with the OAuth2 bearer token "expired-or-invalid-token"
    When I send a GET request to "/store/order/1"
    Then the response status code should be 200

  @getOrderById @boundary
  Scenario Outline: Get an order around the documented valid id ranges (<= 5 or > 10)
    Given orders with ids "1,2,3,4,5,6,10,11" exist
    When I send a GET request to "/store/order/<orderId>"
    Then the response status code should be one of "<codes>"

    Examples:
      | description               | orderId | codes       |
      | lower valid range edge    | 5       | 200         |
      | just above lower range    | 6       | 200,400,404 |
      | upper end of error range  | 10      | 200,400,404 |
      | just inside upper range   | 11      | 200         |

  @getOrderById @boundary
  Scenario Outline: Get an order with extreme id values
    When I send a GET request to "/store/order/<orderId>"
    Then the response status code should be <code>

    Examples:
      | description         | orderId              | code |
      | zero                | 0                    | 404  |
      | negative            | -1                   | 404  |
      | int64 maximum       | 9223372036854775807  | 404  |
      | int64 minimum       | -9223372036854775808 | 404  |
      | int64 max overflow  | 9223372036854775808  | 400  |
      | int64 min underflow | -9223372036854775809 | 400  |

  # ---------------------------------------------------------------------------
  # DELETE /store/order/{orderId}  (deleteOrder)
  # ---------------------------------------------------------------------------

  @deleteOrder @positive
  Scenario: Delete an existing order
    Given an order with id 301 and petId 1 exists
    When I send a DELETE request to "/store/order/301"
    Then the response status code should be 200
    When I send a GET request to "/store/order/301"
    Then the response status code should be 404

  @deleteOrder @negative
  Scenario Outline: Reject deleting an order with a non-integer id
    When I send a DELETE request to "/store/order/<orderId>"
    Then the response status code should be 400

    Examples:
      | orderId |
      | abc     |
      | 1.5     |
      | null    |

  @deleteOrder @negative
  Scenario: Deleting an order that does not exist
    Given no order with id 399 exists
    When I send a DELETE request to "/store/order/399"
    Then the response status code should be one of "200,404"

  @deleteOrder @auth
  Scenario: Delete an order without credentials (endpoint is public per spec)
    Given an order with id 302 and petId 1 exists
    And I am not authenticated
    When I send a DELETE request to "/store/order/302"
    Then the response status code should be 200

  @deleteOrder @auth
  Scenario: An invalid api_key does not block deleting an order
    Given an order with id 303 and petId 1 exists
    And the request header "api_key" is "not-a-real-key"
    When I send a DELETE request to "/store/order/303"
    Then the response status code should be 200

  @deleteOrder @boundary
  Scenario Outline: Delete an order around the documented 1000 id limit
    Given an order with id <orderId> and petId 1 exists
    When I send a DELETE request to "/store/order/<orderId>"
    Then the response status code should be one of "<codes>"

    Examples:
      | description           | orderId | codes       |
      | minimum positive id   | 1       | 200         |
      | just below the limit  | 999     | 200         |
      | at the limit          | 1000    | 200,400,404 |
      | just above the limit  | 1001    | 200,400,404 |

  @deleteOrder @boundary
  Scenario Outline: Delete an order with extreme id values
    When I send a DELETE request to "/store/order/<orderId>"
    Then the response status code should be one of "<codes>"

    Examples:
      | orderId              | codes   |
      | 0                    | 200,404 |
      | -1                   | 200,404 |
      | 9223372036854775807  | 200,404 |
      | 9223372036854775808  | 400     |
      | -9223372036854775809 | 400     |

  @deleteOrder @boundary
  Scenario: Deleting the same order twice
    Given an order with id 304 and petId 1 exists
    When I send a DELETE request to "/store/order/304"
    Then the response status code should be 200
    When I send a DELETE request to "/store/order/304"
    Then the response status code should be one of "200,404"
