@pet
Feature: Pet resource
  As a Petstore API client
  I want to create, read, update, search and delete pets
  So that the store's pet catalogue stays accurate

  Endpoints covered (src/main/resources/openapi.yaml, tag "pet"):
    PUT    /pet                       updatePet          petstore_auth (write:pets, read:pets)
    POST   /pet                       addPet             petstore_auth (write:pets, read:pets)
    GET    /pet/findByStatus          findPetsByStatus   petstore_auth (write:pets, read:pets)
    GET    /pet/findByTags            findPetsByTags     petstore_auth (write:pets, read:pets)
    GET    /pet/{petId}               getPetById         api_key OR petstore_auth
    POST   /pet/{petId}               updatePetWithForm  petstore_auth (write:pets, read:pets)
    DELETE /pet/{petId}               deletePet          petstore_auth (write:pets, read:pets)
    POST   /pet/{petId}/uploadImage   uploadFile         petstore_auth (write:pets, read:pets)

  The spec declares OAuth2 (implicit) and api_key security but no 401/403 responses.
  Scenarios tagged @auth assert 401 for missing/invalid credentials and 403 for
  insufficient scope, which is the expected contract for a secured deployment.

  Scenarios tagged @known-gap fail against the current server and are excluded from
  `mvn test`; the @gap-* tag names the missing behavior. Run them with
  -Dcucumber.filter.tags="@known-gap".

  Background:
    Given the Petstore API base URL is "/api/v3"
    And I am authorized with an OAuth2 bearer token with scopes "write:pets,read:pets"
    And the request header "Accept" is "application/json"

  # ---------------------------------------------------------------------------
  # POST /pet  (addPet)
  # ---------------------------------------------------------------------------

  @addPet @positive
  Scenario: Add a new pet with all fields
    Given the request body is:
      """
      {
        "id": 1001,
        "name": "doggie",
        "category": { "id": 1, "name": "Dogs" },
        "photoUrls": ["https://example.com/doggie.png"],
        "tags": [ { "id": 1, "name": "tag1" } ],
        "status": "available"
      }
      """
    When I send a POST request to "/pet" with content type "application/json"
    Then the response status code should be 200
    And the response body should match the "Pet" schema
    And the response field "id" should equal 1001
    And the response field "name" should equal "doggie"
    And the response field "status" should equal "available"

  @addPet @positive
  Scenario: Add a new pet with only the required fields
    Given the request body is:
      """
      { "id": 1002, "name": "minimal", "photoUrls": [] }
      """
    When I send a POST request to "/pet" with content type "application/json"
    Then the response status code should be 200
    And the response field "name" should equal "minimal"
    And the response field "photoUrls" should be an empty array

  @addPet @positive
  Scenario Outline: Add a new pet using the "<contentType>" request format
    Given a valid pet payload with id 1003 and name "format-pet" encoded as "<contentType>"
    And the request header "Accept" is "<accept>"
    When I send a POST request to "/pet" with content type "<contentType>"
    Then the response status code should be 200
    And the response content type should be "<accept>"
    And the response field "name" should equal "format-pet"

    Examples:
      | contentType                       | accept           |
      | application/json                  | application/json |
      | application/xml                   | application/xml  |
      | application/x-www-form-urlencoded | application/json |

  @addPet @positive
  Scenario Outline: Add a new pet with each allowed status
    Given the request body is:
      """
      { "id": 1004, "name": "status-pet", "photoUrls": [], "status": "<status>" }
      """
    When I send a POST request to "/pet" with content type "application/json"
    Then the response status code should be 200
    And the response field "status" should equal "<status>"

    Examples:
      | status    |
      | available |
      | pending   |
      | sold      |

  @addPet @negative
  Scenario: Reject adding a pet with an empty request body
    When I send a POST request to "/pet" with content type "application/json" and no body
    Then the response status code should be 400

  @addPet @negative
  Scenario: Reject adding a pet with malformed JSON
    Given the request body is:
      """
      { "id": 1005, "name": "broken", "photoUrls": [
      """
    When I send a POST request to "/pet" with content type "application/json"
    Then the response status code should be 400

  @addPet @negative
  Scenario Outline: Reject adding a pet that is missing a required field
    Given the request body is:
      """
      <body>
      """
    When I send a POST request to "/pet" with content type "application/json"
    Then the response status code should be one of "400,422"

    @known-gap @gap-input-validation
    Examples:
      | body                                    |
      | { "id": 1006, "photoUrls": [] }         |
      | { "id": 1007, "name": "no-photo-urls" } |

  @addPet @negative
  Scenario Outline: Reject adding a pet with an invalid field value
    Given the request body is:
      """
      <body>
      """
    When I send a POST request to "/pet" with content type "application/json"
    Then the response status code should be one of "400,422"

    Examples:
      | description              | body                                                                      |
      | id is a string           | { "id": "abc", "name": "x", "photoUrls": [] }                             |
      | photoUrls is not array   | { "id": 1010, "name": "x", "photoUrls": "https://example.com/a.png" }     |
      | tags is not array        | { "id": 1011, "name": "x", "photoUrls": [], "tags": { "name": "tag1" } }  |
      | category id is a string  | { "id": 1012, "name": "x", "photoUrls": [], "category": { "id": "one" } } |

    @known-gap @gap-input-validation
    Examples: known gaps
      | description              | body                                                                      |
      | status not in enum       | { "id": 1008, "name": "x", "photoUrls": [], "status": "lost" }            |
      | name is a number         | { "id": 1009, "name": 123, "photoUrls": [] }                              |

  @addPet @negative
  Scenario: Reject adding a pet with an unsupported content type
    Given the request body is "name=doggie"
    When I send a POST request to "/pet" with content type "text/plain"
    Then the response status code should be 415

  @addPet @auth @known-gap @gap-auth
  Scenario: Reject adding a pet without credentials
    Given I am not authenticated
    And a valid pet payload with id 1013 and name "anon-pet" encoded as "application/json"
    When I send a POST request to "/pet" with content type "application/json"
    Then the response status code should be 401

  @addPet @auth @known-gap @gap-auth
  Scenario: Reject adding a pet with an invalid or expired OAuth2 token
    Given I am authorized with the OAuth2 bearer token "expired-or-invalid-token"
    And a valid pet payload with id 1014 and name "bad-token-pet" encoded as "application/json"
    When I send a POST request to "/pet" with content type "application/json"
    Then the response status code should be 401

  @addPet @auth @known-gap @gap-auth
  Scenario: Reject adding a pet with a token that lacks the write:pets scope
    Given I am authorized with an OAuth2 bearer token with scopes "read:pets"
    And a valid pet payload with id 1015 and name "read-only-pet" encoded as "application/json"
    When I send a POST request to "/pet" with content type "application/json"
    Then the response status code should be 403

  @addPet @auth @known-gap @gap-auth
  Scenario: Reject adding a pet using only an api_key (api_key is not accepted for addPet)
    Given I am not authenticated
    And the request header "api_key" is "special-key"
    And a valid pet payload with id 1016 and name "api-key-pet" encoded as "application/json"
    When I send a POST request to "/pet" with content type "application/json"
    Then the response status code should be 401

  @addPet @boundary
  Scenario Outline: Add a pet with boundary id values
    Given the resource at "/pet/<id>" is deleted after the scenario
    And the request body is:
      """
      { "id": <id>, "name": "boundary-id", "photoUrls": [] }
      """
    When I send a POST request to "/pet" with content type "application/json"
    Then the response status code should be <status>

    Examples:
      | description         | id                   | status |
      | zero                | 0                    | 200    |
      | minimum positive    | 1                    | 200    |
      | int64 maximum       | 9223372036854775807  | 200    |
      | int64 minimum       | -9223372036854775808 | 200    |
      | int64 max overflow  | 9223372036854775808  | 400    |
      | int64 min underflow | -9223372036854775809 | 400    |

    @known-gap @gap-input-validation
    Examples: known gaps
      | description         | id                   | status |
      | decimal value       | 10.5                 | 400    |

  @addPet @boundary
  Scenario Outline: Add a pet with boundary name lengths
    Given a pet payload with id 1020 and a name of <length> characters
    When I send a POST request to "/pet" with content type "application/json"
    Then the response status code should be 200
    And the response field "name" should have length <length>

    Examples:
      | length |
      | 0      |
      | 1      |
      | 255    |
      | 10000  |

  @addPet @boundary
  Scenario: Add a pet whose name contains unicode and special characters
    Given the request body is:
      """
      { "id": 1021, "name": "Rex 🐶 <script>&\"'", "photoUrls": [] }
      """
    When I send a POST request to "/pet" with content type "application/json"
    Then the response status code should be 200
    And the response field "name" should equal "Rex 🐶 <script>&\"'"

  @addPet @boundary
  Scenario: Add a pet with many photo URLs and tags
    Given a pet payload with id 1022, 100 photo URLs and 100 tags
    When I send a POST request to "/pet" with content type "application/json"
    Then the response status code should be 200
    And the response field "photoUrls" should have 100 items
    And the response field "tags" should have 100 items

  @addPet @boundary
  Scenario: Adding a pet with an existing id is handled deterministically
    Given a pet with id 1023 and name "original" exists
    And the request body is:
      """
      { "id": 1023, "name": "duplicate", "photoUrls": [] }
      """
    When I send a POST request to "/pet" with content type "application/json"
    Then the response status code should be 200
    When I send a GET request to "/pet/1023"
    Then the response status code should be 200
    And the response field "id" should equal 1023

  # ---------------------------------------------------------------------------
  # PUT /pet  (updatePet)
  # ---------------------------------------------------------------------------

  @updatePet @positive
  Scenario: Update an existing pet
    Given a pet with id 2001 and name "before-update" exists
    And the request body is:
      """
      {
        "id": 2001,
        "name": "after-update",
        "category": { "id": 2, "name": "Cats" },
        "photoUrls": ["https://example.com/after.png"],
        "tags": [ { "id": 2, "name": "tag2" } ],
        "status": "sold"
      }
      """
    When I send a PUT request to "/pet" with content type "application/json"
    Then the response status code should be 200
    And the response body should match the "Pet" schema
    And the response field "name" should equal "after-update"
    And the response field "status" should equal "sold"
    When I send a GET request to "/pet/2001"
    Then the response field "name" should equal "after-update"

  @updatePet @positive
  Scenario Outline: Update an existing pet using the "<contentType>" request format
    Given a pet with id 2002 and name "format-before" exists
    And a valid pet payload with id 2002 and name "format-after" encoded as "<contentType>"
    When I send a PUT request to "/pet" with content type "<contentType>"
    Then the response status code should be 200
    And the response field "name" should equal "format-after"

    Examples:
      | contentType                       |
      | application/json                  |
      | application/xml                   |
      | application/x-www-form-urlencoded |

  @updatePet @negative
  Scenario: Updating a pet that does not exist returns 404
    Given no pet with id 2999 exists
    And a valid pet payload with id 2999 and name "ghost" encoded as "application/json"
    When I send a PUT request to "/pet" with content type "application/json"
    Then the response status code should be 404
    And the response body should contain "Pet not found"

  @updatePet @negative
  Scenario: Reject updating a pet with an empty request body
    When I send a PUT request to "/pet" with content type "application/json" and no body
    Then the response status code should be 400

  @updatePet @negative
  Scenario Outline: Reject updating a pet with an invalid payload
    Given a pet with id 2003 and name "valid" exists
    And the request body is:
      """
      <body>
      """
    When I send a PUT request to "/pet" with content type "application/json"
    Then the response status code should be one of "400,422"

    Examples:
      | description        | body                                                           |
      | invalid id type    | { "id": "abc", "name": "x", "photoUrls": [] }                  |
      | malformed JSON     | { "id": 2003, "name":                                          |

    @known-gap @gap-input-validation
    Examples: known gaps
      | description        | body                                                           |
      | missing name       | { "id": 2003, "photoUrls": [] }                                |
      | missing photoUrls  | { "id": 2003, "name": "x" }                                    |
      | status not in enum | { "id": 2003, "name": "x", "photoUrls": [], "status": "gone" } |

  @updatePet @auth @known-gap @gap-auth
  Scenario: Reject updating a pet without credentials
    Given a pet with id 2004 and name "secure" exists
    And I am not authenticated
    And a valid pet payload with id 2004 and name "hijacked" encoded as "application/json"
    When I send a PUT request to "/pet" with content type "application/json"
    Then the response status code should be 401

  @updatePet @auth @known-gap @gap-auth
  Scenario: Reject updating a pet with a token that lacks the write:pets scope
    Given a pet with id 2005 and name "secure" exists
    And I am authorized with an OAuth2 bearer token with scopes "read:pets"
    And a valid pet payload with id 2005 and name "hijacked" encoded as "application/json"
    When I send a PUT request to "/pet" with content type "application/json"
    Then the response status code should be 403

  @updatePet @boundary
  Scenario Outline: Update a pet with boundary id values
    Given a valid pet payload with id <id> and name "boundary" encoded as "application/json"
    When I send a PUT request to "/pet" with content type "application/json"
    Then the response status code should be <status>

    Examples:
      | description              | id                  | status |
      | zero (non-existent)      | 0                   | 404    |
      | negative (non-existent)  | -1                  | 404    |
      | int64 max (non-existent) | 9223372036854775807 | 404    |
      | int64 overflow           | 9223372036854775808 | 400    |

  # ---------------------------------------------------------------------------
  # GET /pet/findByStatus  (findPetsByStatus)
  # ---------------------------------------------------------------------------

  @findPetsByStatus @positive
  Scenario Outline: Find pets by a single status
    When I send a GET request to "/pet/findByStatus?status=<status>"
    Then the response status code should be 200
    And the response body should be an array of "Pet" schema items
    And every item in the response should have "status" equal to "<status>"

    Examples:
      | status    |
      | available |
      | pending   |
      | sold      |

  @findPetsByStatus @negative
  Scenario: Comma-separated statuses are rejected because status is a single enum value
    When I send a GET request to "/pet/findByStatus?status=available,sold"
    Then the response status code should be 400

  @findPetsByStatus @positive
  Scenario: Find pets by status and receive XML
    Given the request header "Accept" is "application/xml"
    When I send a GET request to "/pet/findByStatus?status=available"
    Then the response status code should be 200
    And the response content type should be "application/xml"

  @findPetsByStatus @negative
  Scenario: Reject a status value that is not in the enum
    When I send a GET request to "/pet/findByStatus?status=unknown"
    Then the response status code should be 400

  @findPetsByStatus @negative
  Scenario: Reject a request that omits the required status parameter
    When I send a GET request to "/pet/findByStatus"
    Then the response status code should be 400

  @findPetsByStatus @auth @known-gap @gap-auth
  Scenario: Reject finding pets by status without credentials
    Given I am not authenticated
    When I send a GET request to "/pet/findByStatus?status=available"
    Then the response status code should be 401

  @findPetsByStatus @auth @known-gap @gap-auth
  Scenario: Reject finding pets by status with a token lacking the read:pets scope
    Given I am authorized with an OAuth2 bearer token with scopes "write:pets"
    When I send a GET request to "/pet/findByStatus?status=available"
    Then the response status code should be 403

  @findPetsByStatus @boundary
  Scenario Outline: Find pets by status with edge-case parameter values
    When I send a GET request to "/pet/findByStatus?status=<status>"
    Then the response status code should be <code>

    Examples:
      | description                      | status                  | code |
      | empty value                      |                         | 400  |
      | wrong case                       | AVAILABLE               | 400  |
      | trailing comma                   | available,              | 400  |
      | all statuses                     | available,pending,sold  | 400  |
      | duplicated status                | available,available     | 400  |
      | surrounding whitespace (encoded) | %20available%20         | 400  |

  @findPetsByStatus @boundary
  Scenario: Find pets by status when no pet has that status returns an empty array
    Given no pet has status "pending"
    When I send a GET request to "/pet/findByStatus?status=pending"
    Then the response status code should be 200
    And the response body should be an empty array

  # ---------------------------------------------------------------------------
  # GET /pet/findByTags  (findPetsByTags)
  # ---------------------------------------------------------------------------

  @findPetsByTags @positive
  Scenario: Find pets by a single tag
    When I send a GET request to "/pet/findByTags?tags=tag1"
    Then the response status code should be 200
    And the response body should be an array of "Pet" schema items
    And every item in the response should have a tag named "tag1"

  @findPetsByTags @positive
  Scenario Outline: Find pets by multiple tags
    When I send a GET request to "/pet/findByTags?<query>"
    Then the response status code should be 200
    And every item in the response should have at least one tag in "tag1,tag2"

    Examples:
      | style                 | query                |
      | exploded query params | tags=tag1&tags=tag2  |

  @findPetsByTags @boundary
  Scenario: Comma-separated tags are one literal tag value because tags uses explode=true
    When I send a GET request to "/pet/findByTags?tags=tag1,tag2"
    Then the response status code should be 200
    And the response body should be an empty array

  @findPetsByTags @negative
  Scenario: Reject a request that omits the required tags parameter
    When I send a GET request to "/pet/findByTags"
    Then the response status code should be 400
    And the response body should contain "tags"

  @findPetsByTags @auth @known-gap @gap-auth
  Scenario: Reject finding pets by tags without credentials
    Given I am not authenticated
    When I send a GET request to "/pet/findByTags?tags=tag1"
    Then the response status code should be 401

  @findPetsByTags @auth @known-gap @gap-auth
  Scenario: Reject finding pets by tags with an invalid OAuth2 token
    Given I am authorized with the OAuth2 bearer token "expired-or-invalid-token"
    When I send a GET request to "/pet/findByTags?tags=tag1"
    Then the response status code should be 401

  @findPetsByTags @boundary
  Scenario Outline: Find pets by tags with edge-case values
    When I send a GET request to "/pet/findByTags?tags=<tags>"
    Then the response status code should be <code>

    Examples:
      | description              | tags                 | code |
      | empty tag value          |                      | 400  |
      | tag that matches nothing | no-such-tag-xyz      | 200  |
      | url-encoded special char | tag%20with%26symbols | 200  |

  @findPetsByTags @boundary
  Scenario: Find pets by a very long tag value
    Given the query parameter "tags" is a string of 1000 characters
    When I send a GET request to "/pet/findByTags"
    Then the response status code should be 200
    And the response body should be an empty array

  @findPetsByTags @boundary
  Scenario: Find pets by a tag that matches nothing returns an empty array
    When I send a GET request to "/pet/findByTags?tags=no-such-tag-xyz"
    Then the response status code should be 200
    And the response body should be an empty array

  # ---------------------------------------------------------------------------
  # GET /pet/{petId}  (getPetById)
  # ---------------------------------------------------------------------------

  @getPetById @positive
  Scenario: Get an existing pet by id with an OAuth2 token
    Given a pet with id 3001 and name "lookup" exists
    When I send a GET request to "/pet/3001"
    Then the response status code should be 200
    And the response body should match the "Pet" schema
    And the response field "id" should equal 3001
    And the response field "name" should equal "lookup"

  @getPetById @positive
  Scenario: Get an existing pet by id with an api_key instead of OAuth2
    Given a pet with id 3002 and name "api-key-lookup" exists
    And I am not authenticated
    And the request header "api_key" is "special-key"
    When I send a GET request to "/pet/3002"
    Then the response status code should be 200
    And the response field "name" should equal "api-key-lookup"

  @getPetById @positive
  Scenario Outline: Get a pet by id in the "<accept>" format
    Given a pet with id 3003 and name "negotiated" exists
    And the request header "Accept" is "<accept>"
    When I send a GET request to "/pet/3003"
    Then the response status code should be 200
    And the response content type should be "<accept>"

    Examples:
      | accept           |
      | application/json |
      | application/xml  |

  @getPetById @negative
  Scenario: Get a pet that does not exist returns 404
    Given no pet with id 3999 exists
    When I send a GET request to "/pet/3999"
    Then the response status code should be 404
    And the response body should contain "Pet not found"

  @getPetById @negative
  Scenario Outline: Reject a non-integer pet id
    When I send a GET request to "/pet/<petId>"
    Then the response status code should be 400

    Examples:
      | petId |
      | abc   |
      | 1.5   |
      | true  |
      | %20   |

  @getPetById @auth @known-gap @gap-auth
  Scenario: Reject getting a pet with neither api_key nor OAuth2 token
    Given I am not authenticated
    When I send a GET request to "/pet/1"
    Then the response status code should be 401

  @getPetById @auth @known-gap @gap-auth
  Scenario: Reject getting a pet with an invalid api_key
    Given I am not authenticated
    And the request header "api_key" is "invalid-key"
    When I send a GET request to "/pet/1"
    Then the response status code should be 401

  @getPetById @boundary
  Scenario Outline: Get a pet with boundary id values
    When I send a GET request to "/pet/<petId>"
    Then the response status code should be <code>

    Examples:
      | description         | petId                | code |
      | zero                | 0                    | 404  |
      | negative            | -1                   | 404  |
      | int64 maximum       | 9223372036854775807  | 404  |
      | int64 minimum       | -9223372036854775808 | 404  |
      | int64 max overflow  | 9223372036854775808  | 400  |
      | int64 min underflow | -9223372036854775809 | 400  |
      | leading zeros       | 0001                 | 200  |

  # ---------------------------------------------------------------------------
  # POST /pet/{petId}  (updatePetWithForm)
  # ---------------------------------------------------------------------------

  @updatePetWithForm @positive
  Scenario: Update a pet's name and status with query parameters
    Given a pet with id 4001 and name "form-before" exists
    When I send a POST request to "/pet/4001?name=form-after&status=sold"
    Then the response status code should be 200
    And the response body should match the "Pet" schema
    And the response field "name" should equal "form-after"
    And the response field "status" should equal "sold"

  @updatePetWithForm @positive
  Scenario: Update only a pet's name
    Given a pet with id 4002 and name "name-only" exists
    When I send a POST request to "/pet/4002?name=renamed"
    Then the response status code should be 200
    And the response field "name" should equal "renamed"

  @updatePetWithForm @negative
  Scenario: Reject a form update without the name parameter
    Given a pet with id 4003 and name "needs-name" exists
    When I send a POST request to "/pet/4003?status=sold"
    Then the response status code should be 400
    And the response body should contain "No Name provided"

  @updatePetWithForm @negative
  Scenario: Form update on a pet that does not exist returns 404
    Given no pet with id 4999 exists
    When I send a POST request to "/pet/4999?name=ghost"
    Then the response status code should be 404
    And the response body should contain "Pet not found"

  @updatePetWithForm @negative
  Scenario: Reject a form update with a non-integer pet id
    When I send a POST request to "/pet/abc?name=x"
    Then the response status code should be 400

  @updatePetWithForm @negative @known-gap @gap-input-validation
  Scenario: Reject a form update with a status outside the Pet status enum
    Given a pet with id 4004 and name "status-check" exists
    When I send a POST request to "/pet/4004?name=x&status=lost"
    Then the response status code should be 400

  @updatePetWithForm @auth @known-gap @gap-auth
  Scenario: Reject a form update without credentials
    Given a pet with id 4005 and name "secure" exists
    And I am not authenticated
    When I send a POST request to "/pet/4005?name=hijacked"
    Then the response status code should be 401

  @updatePetWithForm @auth @known-gap @gap-auth
  Scenario: Reject a form update with a token lacking the write:pets scope
    Given a pet with id 4006 and name "secure" exists
    And I am authorized with an OAuth2 bearer token with scopes "read:pets"
    When I send a POST request to "/pet/4006?name=hijacked"
    Then the response status code should be 403

  @updatePetWithForm @boundary
  Scenario Outline: Form update with boundary name values
    Given a pet with id 4007 and name "boundary" exists
    When I send a POST request to "/pet/4007?name=<name>"
    Then the response status code should be <code>

    Examples:
      | description         | name               | code |
      | single character    | a                  | 200  |
      | url-encoded unicode | %F0%9F%90%B6       | 200  |
      | encoded spaces      | Mr%20Whiskers      | 200  |

    @known-gap @gap-input-validation
    Examples: known gaps
      | description         | name               | code |
      | empty name          |                    | 400  |

  @updatePetWithForm @boundary
  Scenario: Form update with a very long name
    Given a pet with id 4008 and name "long-name" exists
    And the query parameter "name" is a string of 1000 characters
    When I send a POST request to "/pet/4008"
    Then the response status code should be 200
    And the response field "name" should have length 1000

  @updatePetWithForm @boundary
  Scenario Outline: Form update with boundary pet id values
    When I send a POST request to "/pet/<petId>?name=x"
    Then the response status code should be <code>

    Examples:
      | petId               | code |
      | 0                   | 404  |
      | -1                  | 404  |
      | 9223372036854775807 | 404  |
      | 9223372036854775808 | 400  |

  # ---------------------------------------------------------------------------
  # DELETE /pet/{petId}  (deletePet)
  # ---------------------------------------------------------------------------

  @deletePet @positive
  Scenario: Delete an existing pet
    Given a pet with id 5001 and name "to-delete" exists
    When I send a DELETE request to "/pet/5001"
    Then the response status code should be 200
    And the response body should contain "Pet deleted"
    When I send a GET request to "/pet/5001"
    Then the response status code should be 404

  @deletePet @positive
  Scenario: Delete an existing pet while also sending the optional api_key header
    Given a pet with id 5002 and name "to-delete-with-key" exists
    And the request header "api_key" is "special-key"
    When I send a DELETE request to "/pet/5002"
    Then the response status code should be 200

  @deletePet @negative
  Scenario Outline: Reject deleting a pet with an invalid id
    When I send a DELETE request to "/pet/<petId>"
    Then the response status code should be 400

    Examples:
      | petId |
      | abc   |
      | 1.5   |
      | null  |

  @deletePet @negative
  Scenario: Deleting a pet that does not exist is idempotent
    Given no pet with id 5999 exists
    When I send a DELETE request to "/pet/5999"
    Then the response status code should be one of "200,404"

  @deletePet @auth @known-gap @gap-auth
  Scenario: Reject deleting a pet without credentials
    Given a pet with id 5003 and name "protected" exists
    And I am not authenticated
    When I send a DELETE request to "/pet/5003"
    Then the response status code should be 401
    And a pet with id 5003 should still exist

  @deletePet @auth @known-gap @gap-auth
  Scenario: Reject deleting a pet with only the api_key header (OAuth2 required)
    Given a pet with id 5004 and name "protected" exists
    And I am not authenticated
    And the request header "api_key" is "special-key"
    When I send a DELETE request to "/pet/5004"
    Then the response status code should be 401

  @deletePet @auth @known-gap @gap-auth
  Scenario: Reject deleting a pet with a token lacking the write:pets scope
    Given a pet with id 5005 and name "protected" exists
    And I am authorized with an OAuth2 bearer token with scopes "read:pets"
    When I send a DELETE request to "/pet/5005"
    Then the response status code should be 403

  @deletePet @boundary
  Scenario Outline: Delete a pet with boundary id values
    When I send a DELETE request to "/pet/<petId>"
    Then the response status code should be one of "<code>"

    Examples:
      | petId                | code    |
      | 0                    | 200,404 |
      | -1                   | 200,404 |
      | 9223372036854775807  | 200,404 |
      | 9223372036854775808  | 400     |
      | -9223372036854775809 | 400     |

  @deletePet @boundary
  Scenario: Deleting the same pet twice
    Given a pet with id 5006 and name "delete-twice" exists
    When I send a DELETE request to "/pet/5006"
    Then the response status code should be 200
    When I send a DELETE request to "/pet/5006"
    Then the response status code should be one of "200,404"

  # ---------------------------------------------------------------------------
  # POST /pet/{petId}/uploadImage  (uploadFile)
  # ---------------------------------------------------------------------------

  @uploadFile @positive
  Scenario: Upload an image for an existing pet
    Given a pet with id 6001 and name "photogenic" exists
    And the request body is the binary file "fixtures/dog.png"
    When I send a POST request to "/pet/6001/uploadImage" with content type "application/octet-stream"
    Then the response status code should be 200
    And the response body should match the "ApiResponse" schema

  @uploadFile @positive
  Scenario: Upload an image with additional metadata
    Given a pet with id 6002 and name "with-metadata" exists
    And the request body is the binary file "fixtures/dog.png"
    When I send a POST request to "/pet/6002/uploadImage?additionalMetadata=front%20view" with content type "application/octet-stream"
    Then the response status code should be 200

  @uploadFile @negative
  Scenario: Reject an upload with no file
    Given a pet with id 6003 and name "no-file" exists
    When I send a POST request to "/pet/6003/uploadImage" with content type "application/octet-stream" and no body
    Then the response status code should be 400

  @uploadFile @negative
  Scenario: Upload an image for a pet that does not exist returns 404
    Given no pet with id 6999 exists
    And the request body is the binary file "fixtures/dog.png"
    When I send a POST request to "/pet/6999/uploadImage" with content type "application/octet-stream"
    Then the response status code should be 404
    And the response body should contain "Pet not found"

  @uploadFile @negative
  Scenario: Reject an upload with a non-integer pet id
    Given the request body is the binary file "fixtures/dog.png"
    When I send a POST request to "/pet/abc/uploadImage" with content type "application/octet-stream"
    Then the response status code should be 400

  @uploadFile @negative
  Scenario: Reject an upload with an unsupported content type
    Given a pet with id 6004 and name "multipart" exists
    And the request body is the binary file "fixtures/dog.png"
    When I send a POST request to "/pet/6004/uploadImage" with content type "multipart/form-data"
    Then the response status code should be 415

  @uploadFile @auth @known-gap @gap-auth
  Scenario: Reject an upload without credentials
    Given a pet with id 6005 and name "secure-photo" exists
    And I am not authenticated
    And the request body is the binary file "fixtures/dog.png"
    When I send a POST request to "/pet/6005/uploadImage" with content type "application/octet-stream"
    Then the response status code should be 401

  @uploadFile @auth @known-gap @gap-auth
  Scenario: Reject an upload with a token lacking the write:pets scope
    Given a pet with id 6006 and name "secure-photo" exists
    And I am authorized with an OAuth2 bearer token with scopes "read:pets"
    And the request body is the binary file "fixtures/dog.png"
    When I send a POST request to "/pet/6006/uploadImage" with content type "application/octet-stream"
    Then the response status code should be 403

  @uploadFile @boundary
  Scenario Outline: Upload files of boundary sizes
    Given a pet with id 6007 and name "sizes" exists
    And the request body is a binary payload of <bytes> bytes
    When I send a POST request to "/pet/6007/uploadImage" with content type "application/octet-stream"
    Then the response status code should be <code>

    Examples:
      | description  | bytes    | code |
      | empty file   | 0        | 400  |
      | single byte  | 1        | 200  |
      | 1 MiB file   | 1048576  | 200  |
      | 10 MiB file  | 10485760 | 200  |

  @uploadFile @boundary
  Scenario Outline: Upload an image with boundary pet id values
    Given the request body is the binary file "fixtures/dog.png"
    When I send a POST request to "/pet/<petId>/uploadImage" with content type "application/octet-stream"
    Then the response status code should be <code>

    Examples:
      | petId               | code |
      | 0                   | 404  |
      | -1                  | 404  |
      | 9223372036854775807 | 404  |
      | 9223372036854775808 | 400  |
