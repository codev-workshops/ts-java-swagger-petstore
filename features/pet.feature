Feature: Pet resource
  Everything about your Pets.
  Operations under the "pet" tag of src/main/resources/openapi.yaml:
  updatePet, addPet, findPetsByStatus, findPetsByTags, getPetById,
  listPetPhotos, updatePetWithForm, deletePet, uploadFile.

  Background:
    Given the API base URL is "https://petstore3.swagger.io/api/v3"
    And the request header "Accept" is "application/json"
    And I hold a valid "petstore_auth" OAuth2 token with scopes:
      | scope      |
      | write:pets |
      | read:pets  |

  # ---------------------------------------------------------------------------
  # addPet - POST /pet
  # ---------------------------------------------------------------------------

  Scenario: addPet - create a new pet with a full Pet payload
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      {
        "id": 10,
        "name": "doggie",
        "category": { "id": 1, "name": "Dogs" },
        "photoUrls": [ "https://example.com/photos/doggie-1.jpg" ],
        "tags": [ { "id": 1, "name": "friendly" }, { "id": 2, "name": "trained" } ],
        "status": "available"
      }
      """
    When I send a POST request to "/pet"
    Then the response status code should be 200
    And the response body should match the "Pet" schema
    And the response body should contain the required fields:
      | field     |
      | name      |
      | photoUrls |
    And the response field "name" should be "doggie"
    And the response field "photoUrls" should be an array of strings
    And the response field "category.name" should be "Dogs"
    And the response field "tags" should be an array of "Tag" objects
    And the response field "status" should be one of "available, pending, sold"

  Scenario Outline: addPet - status enum values are accepted
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      {
        "name": "<name>",
        "photoUrls": [ "https://example.com/photos/<name>.jpg" ],
        "status": "<status>"
      }
      """
    When I send a POST request to "/pet"
    Then the response status code should be 200
    And the response field "status" should be "<status>"

    Examples:
      | name   | status    |
      | rex    | available |
      | bella  | pending   |
      | max    | sold      |

  @negative
  Scenario: addPet - malformed JSON body is rejected
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "name": "doggie", "photoUrls": [ "https://example.com/1.jpg", 
      """
    When I send a POST request to "/pet"
    Then the response status code should be 400

  @negative
  Scenario: addPet - status outside the enum is rejected
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      {
        "name": "doggie",
        "photoUrls": [ "https://example.com/photos/doggie-1.jpg" ],
        "status": "adopted"
      }
      """
    When I send a POST request to "/pet"
    Then the response status code should be 400

  @negative
  Scenario Outline: addPet - missing required field raises a validation exception
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      <body>
      """
    When I send a POST request to "/pet"
    Then the response status code should be 422

    Examples:
      | missing   | body                                                        |
      | name      | { "photoUrls": [ "https://example.com/photos/1.jpg" ] }     |
      | photoUrls | { "name": "doggie" }                                        |
      | both      | { "id": 10, "status": "available" }                         |

  @auth @negative
  Scenario: addPet - request without a petstore_auth token is rejected
    Given I do not send any Authorization header
    And the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "name": "doggie", "photoUrls": [ "https://example.com/photos/1.jpg" ] }
      """
    When I send a POST request to "/pet"
    Then the response status code should be 401

  @auth @negative
  Scenario: addPet - request with an invalid petstore_auth token is rejected
    Given the request header "Authorization" is "Bearer invalid-token"
    And the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "name": "doggie", "photoUrls": [ "https://example.com/photos/1.jpg" ] }
      """
    When I send a POST request to "/pet"
    Then the response status code should be 401

  # ---------------------------------------------------------------------------
  # updatePet - PUT /pet
  # ---------------------------------------------------------------------------

  Scenario: updatePet - update an existing pet with a full Pet payload
    Given a pet with id 10 exists
    And the request header "Content-Type" is "application/json"
    And the request body is:
      """
      {
        "id": 10,
        "name": "doggie-renamed",
        "category": { "id": 2, "name": "Cats" },
        "photoUrls": [ "https://example.com/photos/doggie-2.jpg", "https://example.com/photos/doggie-3.jpg" ],
        "tags": [ { "id": 3, "name": "calm" } ],
        "status": "sold"
      }
      """
    When I send a PUT request to "/pet"
    Then the response status code should be 200
    And the response body should match the "Pet" schema
    And the response field "id" should be 10
    And the response field "name" should be "doggie-renamed"
    And the response field "photoUrls" should have 2 items
    And the response field "status" should be "sold"

  @negative
  Scenario: updatePet - invalid id supplied
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "id": "not-a-number", "name": "doggie", "photoUrls": [ "https://example.com/photos/1.jpg" ] }
      """
    When I send a PUT request to "/pet"
    Then the response status code should be 400

  @negative
  Scenario: updatePet - pet not found
    Given no pet with id 999999999 exists
    And the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "id": 999999999, "name": "ghost", "photoUrls": [ "https://example.com/photos/ghost.jpg" ] }
      """
    When I send a PUT request to "/pet"
    Then the response status code should be 404

  @negative
  Scenario Outline: updatePet - missing required field raises a validation exception
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      <body>
      """
    When I send a PUT request to "/pet"
    Then the response status code should be 422

    Examples:
      | missing   | body                                                             |
      | name      | { "id": 10, "photoUrls": [ "https://example.com/photos/1.jpg" ] }|
      | photoUrls | { "id": 10, "name": "doggie" }                                   |

  @auth @negative
  Scenario: updatePet - request without a petstore_auth token is rejected
    Given I do not send any Authorization header
    And the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "id": 10, "name": "doggie", "photoUrls": [ "https://example.com/photos/1.jpg" ] }
      """
    When I send a PUT request to "/pet"
    Then the response status code should be 401

  @auth @negative
  Scenario: updatePet - request with an invalid petstore_auth token is rejected
    Given the request header "Authorization" is "Bearer invalid-token"
    And the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "id": 10, "name": "doggie", "photoUrls": [ "https://example.com/photos/1.jpg" ] }
      """
    When I send a PUT request to "/pet"
    Then the response status code should be 401

  # ---------------------------------------------------------------------------
  # findPetsByStatus - GET /pet/findByStatus
  # ---------------------------------------------------------------------------

  Scenario Outline: findPetsByStatus - each valid status value returns an array of Pet
    When I send a GET request to "/pet/findByStatus?status=<status>"
    Then the response status code should be 200
    And the response body should be a JSON array
    And every item in the response array should match the "Pet" schema
    And every item in the response array should have field "status" equal to "<status>"

    Examples:
      | status    |
      | available |
      | pending   |
      | sold      |

  Scenario: findPetsByStatus - status defaults to "available" when omitted
    When I send a GET request to "/pet/findByStatus"
    Then the response status code should be 200
    And the response body should be a JSON array
    And every item in the response array should have field "status" equal to "available"

  @negative
  Scenario Outline: findPetsByStatus - invalid status value is rejected
    When I send a GET request to "/pet/findByStatus?status=<status>"
    Then the response status code should be 400

    Examples:
      | status   |
      | adopted  |
      | AVAILABLE|
      | 123      |

  @auth @negative
  Scenario: findPetsByStatus - request without a petstore_auth token is rejected
    Given I do not send any Authorization header
    When I send a GET request to "/pet/findByStatus?status=available"
    Then the response status code should be 401

  # ---------------------------------------------------------------------------
  # findPetsByTags - GET /pet/findByTags
  # ---------------------------------------------------------------------------

  Scenario: findPetsByTags - single tag returns an array of Pet
    When I send a GET request to "/pet/findByTags?tags=tag1"
    Then the response status code should be 200
    And the response body should be a JSON array
    And every item in the response array should match the "Pet" schema
    And every item in the response array should have a tag named "tag1"

  Scenario: findPetsByTags - multiple exploded tags return an array of Pet
    When I send a GET request to "/pet/findByTags?tags=tag1&tags=tag2&tags=tag3"
    Then the response status code should be 200
    And the response body should be a JSON array
    And every item in the response array should match the "Pet" schema

  @negative
  Scenario: findPetsByTags - missing required tags parameter is rejected
    When I send a GET request to "/pet/findByTags"
    Then the response status code should be 400

  @negative
  Scenario: findPetsByTags - empty tag value is rejected
    When I send a GET request to "/pet/findByTags?tags="
    Then the response status code should be 400

  @auth @negative
  Scenario: findPetsByTags - request without a petstore_auth token is rejected
    Given I do not send any Authorization header
    When I send a GET request to "/pet/findByTags?tags=tag1"
    Then the response status code should be 401

  # ---------------------------------------------------------------------------
  # getPetById - GET /pet/{petId}
  # Accepts either api_key OR petstore_auth.
  # ---------------------------------------------------------------------------

  Scenario: getPetById - valid id with petstore_auth returns the Pet
    Given a pet with id 10 exists
    When I send a GET request to "/pet/10"
    Then the response status code should be 200
    And the response body should match the "Pet" schema
    And the response field "id" should be 10
    And the response body should contain the required fields:
      | field     |
      | name      |
      | photoUrls |

  @auth
  Scenario: getPetById - valid id with api_key header instead of OAuth2 token
    Given a pet with id 10 exists
    And I do not send any Authorization header
    And the request header "api_key" is "special-key"
    When I send a GET request to "/pet/10"
    Then the response status code should be 200
    And the response body should match the "Pet" schema

  @negative
  Scenario Outline: getPetById - invalid id format is rejected
    When I send a GET request to "/pet/<petId>"
    Then the response status code should be 400

    Examples:
      | petId   |
      | abc     |
      | 1.5     |
      | -1x     |

  @negative
  Scenario: getPetById - pet not found
    Given no pet with id 999999999 exists
    When I send a GET request to "/pet/999999999"
    Then the response status code should be 404

  @auth @negative
  Scenario: getPetById - request with neither api_key nor petstore_auth is rejected
    Given I do not send any Authorization header
    And I do not send an "api_key" header
    When I send a GET request to "/pet/10"
    Then the response status code should be 401

  # ---------------------------------------------------------------------------
  # listPetPhotos - GET /pet/{petId}/photos
  # No security declared; the spec documents only a 200 response.
  # ---------------------------------------------------------------------------

  Scenario: listPetPhotos - valid id returns the pet's photos
    Given a pet with id 10 exists
    And I do not send any Authorization header
    When I send a GET request to "/pet/10/photos"
    Then the response status code should be 200

  @negative
  Scenario Outline: listPetPhotos - invalid id format is rejected
    When I send a GET request to "/pet/<petId>/photos"
    Then the response status code should be 400

    Examples:
      | petId |
      | abc   |
      | 1.5   |
      | -1x   |

  # ---------------------------------------------------------------------------
  # updatePetWithForm - POST /pet/{petId}
  # ---------------------------------------------------------------------------

  Scenario: updatePetWithForm - update name and status via query params
    Given a pet with id 10 exists
    When I send a POST request to "/pet/10?name=doggie-updated&status=pending"
    Then the response status code should be 200
    And the response body should match the "Pet" schema
    And the response field "id" should be 10
    And the response field "name" should be "doggie-updated"
    And the response field "status" should be "pending"

  Scenario Outline: updatePetWithForm - each optional query param may be sent alone
    Given a pet with id 10 exists
    When I send a POST request to "/pet/10?<query>"
    Then the response status code should be 200
    And the response body should match the "Pet" schema
    And the response field "<field>" should be "<value>"

    Examples:
      | query           | field  | value  |
      | name=rex        | name   | rex    |
      | status=sold     | status | sold   |

  @negative
  Scenario Outline: updatePetWithForm - invalid input is rejected
    When I send a POST request to "/pet/<petId>?<query>"
    Then the response status code should be 400

    Examples:
      | petId | query            |
      | abc   | name=rex         |
      | 10    | status=adopted   |

  @auth @negative
  Scenario: updatePetWithForm - request without a petstore_auth token is rejected
    Given I do not send any Authorization header
    When I send a POST request to "/pet/10?name=rex"
    Then the response status code should be 401

  # ---------------------------------------------------------------------------
  # deletePet - DELETE /pet/{petId}
  # ---------------------------------------------------------------------------

  Scenario: deletePet - delete an existing pet
    Given a pet with id 10 exists
    When I send a DELETE request to "/pet/10"
    Then the response status code should be 200
    And a subsequent GET request to "/pet/10" should return status code 404

  Scenario: deletePet - delete with the optional api_key header supplied
    Given a pet with id 11 exists
    And the request header "api_key" is "special-key"
    When I send a DELETE request to "/pet/11"
    Then the response status code should be 200

  @negative
  Scenario Outline: deletePet - invalid pet value is rejected
    When I send a DELETE request to "/pet/<petId>"
    Then the response status code should be 400

    Examples:
      | petId |
      | abc   |
      | 1.5   |

  @auth @negative
  Scenario: deletePet - request without a petstore_auth token is rejected
    Given I do not send any Authorization header
    When I send a DELETE request to "/pet/10"
    Then the response status code should be 401

  # ---------------------------------------------------------------------------
  # uploadFile - POST /pet/{petId}/uploadImage
  # ---------------------------------------------------------------------------

  Scenario: uploadFile - upload an image for an existing pet
    Given a pet with id 10 exists
    And the request header "Content-Type" is "application/octet-stream"
    And the request body is the binary contents of file "fixtures/doggie.jpg"
    When I send a POST request to "/pet/10/uploadImage"
    Then the response status code should be 200
    And the response body should match the "ApiResponse" schema
    And the response field "code" should be an integer
    And the response field "type" should be a string
    And the response field "message" should be a string

  Scenario: uploadFile - upload an image with additionalMetadata
    Given a pet with id 10 exists
    And the request header "Content-Type" is "application/octet-stream"
    And the request body is the binary contents of file "fixtures/doggie.jpg"
    When I send a POST request to "/pet/10/uploadImage?additionalMetadata=front%20view"
    Then the response status code should be 200
    And the response body should match the "ApiResponse" schema
    And the response field "message" should contain "front view"

  @negative
  Scenario: uploadFile - no file uploaded
    Given a pet with id 10 exists
    And the request header "Content-Type" is "application/octet-stream"
    And the request body is empty
    When I send a POST request to "/pet/10/uploadImage"
    Then the response status code should be 400

  @negative
  Scenario: uploadFile - pet not found
    Given no pet with id 999999999 exists
    And the request header "Content-Type" is "application/octet-stream"
    And the request body is the binary contents of file "fixtures/doggie.jpg"
    When I send a POST request to "/pet/999999999/uploadImage"
    Then the response status code should be 404

  @auth @negative
  Scenario: uploadFile - request without a petstore_auth token is rejected
    Given I do not send any Authorization header
    And the request header "Content-Type" is "application/octet-stream"
    And the request body is the binary contents of file "fixtures/doggie.jpg"
    When I send a POST request to "/pet/10/uploadImage"
    Then the response status code should be 401
