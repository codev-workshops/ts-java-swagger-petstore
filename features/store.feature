Feature: Store resource
  Access to Petstore orders.
  Operations under the "store" tag of src/main/resources/openapi.yaml:
  getInventory, placeOrder, getOrderById, deleteOrder.

  Background:
    Given the API base URL is "https://petstore3.swagger.io/api/v3"
    And the request header "Accept" is "application/json"

  # ---------------------------------------------------------------------------
  # getInventory - GET /store/inventory  (security: api_key)
  # ---------------------------------------------------------------------------

  @auth
  Scenario: getInventory - returns a map of status to quantity
    Given the request header "api_key" is "special-key"
    When I send a GET request to "/store/inventory"
    Then the response status code should be 200
    And the response body should be a JSON object
    And every key in the response object should be a string
    And every value in the response object should be an int32 integer

  @auth @negative
  Scenario: getInventory - missing api_key header is rejected
    Given I do not send an "api_key" header
    When I send a GET request to "/store/inventory"
    Then the response status code should be 401

  @auth @negative
  Scenario: getInventory - invalid api_key header is rejected
    Given the request header "api_key" is "invalid-key"
    When I send a GET request to "/store/inventory"
    Then the response status code should be 401

  @negative
  Scenario: getInventory - POST is not allowed
    Given the request header "api_key" is "special-key"
    When I send a POST request to "/store/inventory"
    Then the response status code should be 405

  # ---------------------------------------------------------------------------
  # placeOrder - POST /store/order  (no security)
  # ---------------------------------------------------------------------------

  Scenario: placeOrder - place a valid order
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      {
        "id": 10,
        "petId": 198772,
        "quantity": 7,
        "shipDate": "2026-09-15T09:00:00.000Z",
        "status": "approved",
        "complete": true
      }
      """
    When I send a POST request to "/store/order"
    Then the response status code should be 200
    And the response body should match the "Order" schema
    And the response field "id" should be 10
    And the response field "petId" should be 198772
    And the response field "quantity" should be 7
    And the response field "shipDate" should be a date-time string
    And the response field "status" should be one of "placed, approved, delivered"
    And the response field "complete" should be a boolean

  Scenario Outline: placeOrder - every status enum value is accepted
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      {
        "petId": 198772,
        "quantity": 1,
        "shipDate": "2026-09-15T09:00:00.000Z",
        "status": "<status>",
        "complete": <complete>
      }
      """
    When I send a POST request to "/store/order"
    Then the response status code should be 200
    And the response field "status" should be "<status>"
    And the response field "complete" should be <complete>

    Examples:
      | status    | complete |
      | placed    | false    |
      | approved  | false    |
      | delivered | true     |

  @contract
  Scenario: placeOrder - accepts an XML request body
    Given the request header "Content-Type" is "application/xml"
    And the request body is:
      """
      <Order><id>30</id><petId>198772</petId><quantity>2</quantity><status>placed</status><complete>false</complete></Order>
      """
    When I send a POST request to "/store/order"
    Then the response status code should be 200
    And the response body should match the "Order" schema

  @contract
  Scenario: placeOrder - accepts a form-encoded request body
    Given the request header "Content-Type" is "application/x-www-form-urlencoded"
    And the request body is:
      """
      id=31&petId=198772&quantity=2&status=placed&complete=false
      """
    When I send a POST request to "/store/order"
    Then the response status code should be 200
    And the response body should match the "Order" schema

  @boundary
  Scenario Outline: placeOrder - accepts int32 quantity edges
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "petId": 198772, "quantity": <quantity> }
      """
    When I send a POST request to "/store/order"
    Then the response status code should be 200
    And the response field "quantity" should be <quantity>

    Examples:
      | quantity    |
      | 0           |
      | 1           |
      | 2147483647  |

  @boundary @negative
  Scenario: placeOrder - rejects quantity beyond int32
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "petId": 198772, "quantity": 2147483648 }
      """
    When I send a POST request to "/store/order"
    Then the response status code should be 400

  @boundary
  Scenario: placeOrder - accepts negative quantity
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "petId": 198772, "quantity": -1 }
      """
    When I send a POST request to "/store/order"
    Then the response status code should be 200
    And the response field "quantity" should be -1

  @boundary
  Scenario Outline: placeOrder - accepts petId int64 edges
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "petId": <petId>, "quantity": 1 }
      """
    When I send a POST request to "/store/order"
    Then the response status code should be 200

    Examples:
      | petId               |
      | 0                   |
      | 9223372036854775807 |

  @boundary @negative
  Scenario: placeOrder - rejects petId beyond int64
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "petId": 9223372036854775808, "quantity": 1 }
      """
    When I send a POST request to "/store/order"
    Then the response status code should be 400

  @boundary
  Scenario Outline: placeOrder - accepts timezone and leap-day shipDate values
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "petId": 198772, "quantity": 1, "shipDate": "<shipDate>" }
      """
    When I send a POST request to "/store/order"
    Then the response status code should be 200
    And the response field "shipDate" should be a date-time string

    Examples:
      | shipDate                    |
      | 2026-02-28T23:59:59+02:00  |
      | 2028-02-29T00:00:00Z        |

  @boundary
  Scenario: placeOrder - accepts a minimal body
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      {}
      """
    When I send a POST request to "/store/order"
    Then the response status code should be 200

  @negative
  Scenario: placeOrder - rejects an empty request body
    Given the request header "Content-Type" is "application/json"
    And the request body is empty
    When I send a POST request to "/store/order"
    Then the response status code should be 400

  @negative
  Scenario: placeOrder - malformed JSON body is rejected
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "petId": 198772, "quantity": 
      """
    When I send a POST request to "/store/order"
    Then the response status code should be 400

  @negative
  Scenario Outline: placeOrder - wrong field types are rejected as invalid input
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      <body>
      """
    When I send a POST request to "/store/order"
    Then the response status code should be 400

    Examples:
      | field    | body                                                            |
      | petId    | { "petId": "abc", "quantity": 1 }                               |
      | quantity | { "petId": 198772, "quantity": "seven" }                        |
      | complete | { "petId": 198772, "quantity": 1, "complete": "yes" }           |

  @negative
  Scenario Outline: placeOrder - semantically invalid values raise a validation exception
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      <body>
      """
    When I send a POST request to "/store/order"
    Then the response status code should be 422

    Examples:
      | reason           | body                                                                          |
      | status not enum  | { "petId": 198772, "quantity": 1, "status": "shipped" }                       |
      | bad shipDate     | { "petId": 198772, "quantity": 1, "shipDate": "15/09/2026", "status": "placed" } |

  # ---------------------------------------------------------------------------
  # getOrderById - GET /store/order/{orderId}
  # Spec: "For valid response try integer IDs with value <= 5 or > 10.
  #        Other values will generate exceptions."
  # ---------------------------------------------------------------------------

  Scenario: getOrderById - fetch an existing order
    Given an order with id 1 exists
    When I send a GET request to "/store/order/1"
    Then the response status code should be 200
    And the response body should match the "Order" schema
    And the response field "id" should be 1
    And the response field "status" should be one of "placed, approved, delivered"

  @boundary
  Scenario Outline: getOrderById - ids <= 5 or > 10 are valid
    Given an order with id <orderId> exists
    When I send a GET request to "/store/order/<orderId>"
    Then the response status code should be 200
    And the response body should match the "Order" schema
    And the response field "id" should be <orderId>

    Examples: lower valid range (<= 5)
      | orderId |
      | 1       |
      | 5       |

    Examples: upper valid range (> 10)
      | orderId |
      | 11      |
      | 100     |

  @boundary @negative
  Scenario Outline: getOrderById - ids between 6 and 10 generate errors
    When I send a GET request to "/store/order/<orderId>"
    Then the response status code should be <status>

    Examples:
      | orderId | status |
      | 6       | 404    |
      | 8       | 404    |
      | 10      | 404    |

  @negative
  Scenario Outline: getOrderById - invalid id supplied
    When I send a GET request to "/store/order/<orderId>"
    Then the response status code should be 400

    Examples:
      | orderId |
      | abc     |
      | 1.5     |

  @negative
  Scenario: getOrderById - order not found
    Given no order with id 999999999 exists
    When I send a GET request to "/store/order/999999999"
    Then the response status code should be 404

  @boundary
  Scenario Outline: getOrderById - well-formed int64 unknown ids return 404
    Given no order with id <orderId> exists
    When I send a GET request to "/store/order/<orderId>"
    Then the response status code should be 404

    Examples:
      | orderId             |
      | 0                   |
      | -1                  |
      | 9223372036854775807 |

  @boundary @negative
  Scenario: getOrderById - rejects an order id beyond int64
    When I send a GET request to "/store/order/9223372036854775808"
    Then the response status code should be 400

  # ---------------------------------------------------------------------------
  # deleteOrder - DELETE /store/order/{orderId}
  # Spec: "For valid response try integer IDs with value < 1000.
  #        Anything above 1000 or non-integers will generate API errors."
  # ---------------------------------------------------------------------------

  Scenario: deleteOrder - delete an existing order
    Given an order with id 1 exists
    When I send a DELETE request to "/store/order/1"
    Then the response status code should be 200
    And a subsequent GET request to "/store/order/1" should return status code 404

  @boundary
  Scenario Outline: deleteOrder - ids below 1000 are valid
    Given an order with id <orderId> exists
    When I send a DELETE request to "/store/order/<orderId>"
    Then the response status code should be 200

    Examples:
      | orderId |
      | 1       |
      | 999     |

  @boundary @negative
  Scenario Outline: deleteOrder - ids at or above 1000 generate errors
    When I send a DELETE request to "/store/order/<orderId>"
    Then the response status code should be <status>

    Examples:
      | orderId | status |
      | 1000    | 400    |
      | 1001    | 400    |
      | 99999   | 400    |

  @negative
  Scenario Outline: deleteOrder - non-integer id supplied
    When I send a DELETE request to "/store/order/<orderId>"
    Then the response status code should be 400

    Examples:
      | orderId |
      | abc     |
      | 1.5     |

  @negative
  Scenario: deleteOrder - order not found
    Given no order with id 500 exists
    When I send a DELETE request to "/store/order/500"
    Then the response status code should be 404

  @boundary
  Scenario: deleteOrder - order id zero is valid
    Given no order with id 0 exists
    When I send a DELETE request to "/store/order/0"
    Then the response status code should be 200

  @boundary @negative
  Scenario: deleteOrder - rejects an order id beyond int64
    When I send a DELETE request to "/store/order/9223372036854775808"
    Then the response status code should be 400

  @boundary
  Scenario: deleteOrder - deleting an already-deleted order is idempotent
    Given an order with id 2 exists
    When I send a DELETE request to "/store/order/2"
    Then the response status code should be 200
    And a subsequent DELETE request to "/store/order/2" should return status code 200
