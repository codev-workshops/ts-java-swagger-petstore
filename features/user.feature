Feature: User resource
  Operations about user.
  Operations under the "user" tag of src/main/resources/openapi.yaml:
  createUser, createUsersWithListInput, loginUser, logoutUser,
  getUserByName, updateUser, deleteUser.
  None of these operations declare a security requirement.

  Background:
    Given the API base URL is "https://petstore3.swagger.io/api/v3"
    And the request header "Accept" is "application/json"

  # ---------------------------------------------------------------------------
  # createUser - POST /user
  # ---------------------------------------------------------------------------

  Scenario: createUser - create a user with a full User payload
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      {
        "id": 10,
        "username": "theUser",
        "firstName": "John",
        "lastName": "James",
        "email": "john@email.com",
        "password": "12345",
        "phone": "12345",
        "userStatus": 1
      }
      """
    When I send a POST request to "/user"
    Then the response status code should be 200
    And the response body should match the "User" schema
    And the response body should contain the fields:
      | field      | type    |
      | id         | integer |
      | username   | string  |
      | firstName  | string  |
      | lastName   | string  |
      | email      | string  |
      | password   | string  |
      | phone      | string  |
      | userStatus | integer |
    And the response field "username" should be "theUser"

  @negative
  Scenario: createUser - malformed JSON body is rejected
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "username": "theUser", "firstName": 
      """
    When I send a POST request to "/user"
    Then the response status code should be 400

  @negative
  Scenario Outline: createUser - wrong field types are rejected
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      <body>
      """
    When I send a POST request to "/user"
    Then the response status code should be 400

    Examples:
      | field      | body                                            |
      | id         | { "id": "ten", "username": "theUser" }          |
      | userStatus | { "username": "theUser", "userStatus": "one" }  |

  @contract
  Scenario: createUser - accepts an XML request body
    Given the request header "Content-Type" is "application/xml"
    And the request body is:
      """
      <User><id>40</id><username>xmluser</username><firstName>X</firstName><lastName>M</lastName><email>x@e.com</email><password>p</password><phone>1</phone><userStatus>1</userStatus></User>
      """
    When I send a POST request to "/user"
    Then the response status code should be 200
    And the response field "username" should be "xmluser"

  @contract
  Scenario: createUser - accepts a form-encoded request body
    Given the request header "Content-Type" is "application/x-www-form-urlencoded"
    And the request body is:
      """
      id=41&username=formuser&firstName=F&lastName=U&email=f%40example.com&password=p&phone=1&userStatus=1
      """
    When I send a POST request to "/user"
    Then the response status code should be 200
    And the response field "username" should be "formuser"

  @boundary
  Scenario Outline: createUser - accepts int32 userStatus edges
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "username": "status-<userStatus>", "userStatus": <userStatus> }
      """
    When I send a POST request to "/user"
    Then the response status code should be 200
    And the response field "userStatus" should be <userStatus>

    Examples:
      | userStatus   |
      | -2147483648  |
      | 0            |
      | 2147483647   |

  @boundary @negative
  Scenario: createUser - rejects userStatus beyond int32
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "username": "status-overflow", "userStatus": 2147483648 }
      """
    When I send a POST request to "/user"
    Then the response status code should be 400

  @boundary @negative
  Scenario: createUser - rejects id beyond int64
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "id": 9223372036854775808, "username": "id-overflow" }
      """
    When I send a POST request to "/user"
    Then the response status code should be 400

  @boundary
  Scenario: createUser - accepts a 255-character username
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "username": "placeholder" }
      """
    And the request body field "username" is a string of 255 characters
    When I send a POST request to "/user"
    Then the response status code should be 200
    And the response field "username" should have length 255
    And a subsequent GET request to "/user/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" should return status code 200

  @boundary
  Scenario: createUser - accepts unicode fields
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "username": "jösé", "firstName": "José", "email": "josé@example.com" }
      """
    When I send a POST request to "/user"
    Then the response status code should be 200
    And the response field "username" should be "jösé"
    And a subsequent GET request to "/user/j%C3%B6s%C3%A9" should return status code 200

  @boundary
  Scenario: createUser - accepts a minimal body
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      {}
      """
    When I send a POST request to "/user"
    Then the response status code should be 200
    And the response body should match the "User" schema

  @negative
  Scenario: createUser - rejects an empty request body
    Given the request header "Content-Type" is "application/json"
    And the request body is empty
    When I send a POST request to "/user"
    Then the response status code should be 400

  # ---------------------------------------------------------------------------
  # createUsersWithListInput - POST /user/createWithList
  # ---------------------------------------------------------------------------

  Scenario: createUsersWithListInput - create several users from an array
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      [
        {
          "id": 11,
          "username": "user1",
          "firstName": "Alice",
          "lastName": "Anderson",
          "email": "alice@email.com",
          "password": "pass1",
          "phone": "1111",
          "userStatus": 1
        },
        {
          "id": 12,
          "username": "user2",
          "firstName": "Bob",
          "lastName": "Brown",
          "email": "bob@email.com",
          "password": "pass2",
          "phone": "2222",
          "userStatus": 1
        }
      ]
      """
    When I send a POST request to "/user/createWithList"
    Then the response status code should be 200
    And the response body should match the "User" schema
    And a subsequent GET request to "/user/user1" should return status code 200
    And a subsequent GET request to "/user/user2" should return status code 200

  @negative
  Scenario: createUsersWithListInput - empty array
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      []
      """
    When I send a POST request to "/user/createWithList"
    Then the response status code should be 400

  @negative
  Scenario Outline: createUsersWithListInput - body that is not an array of User is rejected
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      <body>
      """
    When I send a POST request to "/user/createWithList"
    Then the response status code should be 400

    Examples:
      | reason              | body                                     |
      | single object       | { "username": "user1" }                  |
      | non-object elements | [ "user1", "user2" ]                     |
      | malformed JSON      | [ { "username": "user1" },               |

  @boundary
  Scenario: createUsersWithListInput - accepts a single-element array
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      [{ "id": 1, "username": "singleuser" }]
      """
    When I send a POST request to "/user/createWithList"
    Then the response status code should be 200

  @boundary
  Scenario: createUsersWithListInput - accepts 50 users
    Given the request header "Content-Type" is "application/json"
    And the request body is a JSON array of 50 users with username prefix "bulk"
    When I send a POST request to "/user/createWithList"
    Then the response status code should be 200
    And a subsequent GET request to "/user/bulk1" should return status code 200
    And a subsequent GET request to "/user/bulk50" should return status code 200

  @boundary
  Scenario: createUsersWithListInput - last duplicate username wins
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      [
        { "username": "dupuser", "firstName": "First" },
        { "username": "dupuser", "firstName": "Second" }
      ]
      """
    When I send a POST request to "/user/createWithList"
    Then the response status code should be 200
    And a subsequent GET request to "/user/dupuser" should return field "firstName" equal to "Second"

  # ---------------------------------------------------------------------------
  # loginUser - GET /user/login
  # ---------------------------------------------------------------------------

  Scenario: loginUser - successful login returns rate-limit and expiry headers
    Given a user exists with credentials:
      | username | password |
      | user1    | abc123   |
    When I send a GET request to "/user/login?username=user1&password=abc123"
    Then the response status code should be 200
    And the response body should be a string
    And the response header "X-Rate-Limit" should be present
    And the response header "X-Rate-Limit" should be an int32 integer
    And the response header "X-Expires-After" should be present
    And the response header "X-Expires-After" should be a date-time string

  @negative
  Scenario Outline: loginUser - invalid username/password supplied
    When I send a GET request to "/user/login?username=<username>&password=<password>"
    Then the response status code should be 400

    Examples:
      | username     | password  |
      | user1        | wrongpass |
      | nosuchuser   | abc123    |
      |              | abc123    |
      | user1        |           |

  @boundary @negative
  Scenario: loginUser - missing username and password is rejected
    When I send a GET request to "/user/login"
    Then the response status code should be 400

  @boundary @negative
  Scenario: loginUser - rejects a 255-character password
    When I send a GET request to "/user/login?username=user1&password=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    Then the response status code should be 400

  @boundary
  Scenario: loginUser - response contains the session message
    Given a user exists with credentials:
      | username | password |
      | user1    | abc123   |
    When I send a GET request to "/user/login?username=user1&password=abc123"
    Then the response status code should be 200
    And the response body should contain "Logged in user session"

  # ---------------------------------------------------------------------------
  # logoutUser - GET /user/logout
  # ---------------------------------------------------------------------------

  Scenario: logoutUser - logs out the current session
    Given I am logged in as "user1"
    When I send a GET request to "/user/logout"
    Then the response status code should be 200

  Scenario: logoutUser - logout takes no parameters
    When I send a GET request to "/user/logout"
    Then the response status code should be 200

  @negative
  Scenario: logoutUser - POST is not allowed
    When I send a POST request to "/user/logout"
    Then the response status code should be 405

  @boundary
  Scenario: logoutUser - unknown query parameters are ignored
    When I send a GET request to "/user/logout?force=true"
    Then the response status code should be 200

  @boundary
  Scenario: logoutUser - accepts a request without Accept
    Given I do not send an "Accept" header
    When I send a GET request to "/user/logout"
    Then the response status code should be 200

  # ---------------------------------------------------------------------------
  # getUserByName - GET /user/{username}
  # Spec: "Use user1 for testing"
  # ---------------------------------------------------------------------------

  Scenario: getUserByName - fetch user1
    Given a user with username "user1" exists
    When I send a GET request to "/user/user1"
    Then the response status code should be 200
    And the response body should match the "User" schema
    And the response field "username" should be "user1"
    And the response field "id" should be an integer
    And the response field "userStatus" should be an integer

  @negative
  Scenario Outline: getUserByName - invalid username supplied
    When I send a GET request to "/user/<username>"
    Then the response status code should be 400

    Examples:
      | username          |
      | %20               |
      | user%2Fwith%2Fslash |

  @negative
  Scenario: getUserByName - user not found
    Given no user with username "no-such-user-xyz" exists
    When I send a GET request to "/user/no-such-user-xyz"
    Then the response status code should be 404

  @boundary
  Scenario Outline: getUserByName - accepts punctuation in usernames
    Given a user with username "<username>" exists
    When I send a GET request to "/user/<username>"
    Then the response status code should be 200
    And the response field "username" should be "<username>"

    Examples:
      | username   |
      | user.name  |
      | user-name  |
      | user_name  |

  @boundary
  Scenario: getUserByName - usernames are case-sensitive
    Given a user with username "user1" exists
    When I send a GET request to "/user/USER1"
    Then the response status code should be 404

  @boundary
  Scenario: getUserByName - accepts a 255-character username
    Given the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "username": "placeholder" }
      """
    And the request body field "username" is a string of 255 characters
    When I send a POST request to "/user"
    Then the response status code should be 200
    And a subsequent GET request to "/user/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" should return status code 200

  # ---------------------------------------------------------------------------
  # updateUser - PUT /user/{username}
  # ---------------------------------------------------------------------------

  Scenario: updateUser - update an existing user
    Given a user with username "user1" exists
    And the request header "Content-Type" is "application/json"
    And the request body is:
      """
      {
        "id": 11,
        "username": "user1",
        "firstName": "Alicia",
        "lastName": "Anderson-Smith",
        "email": "alicia@email.com",
        "password": "newpass",
        "phone": "9999",
        "userStatus": 2
      }
      """
    When I send a PUT request to "/user/user1"
    Then the response status code should be 200
    And a subsequent GET request to "/user/user1" should return field "firstName" equal to "Alicia"
    And a subsequent GET request to "/user/user1" should return field "userStatus" equal to 2

  @negative
  Scenario: updateUser - malformed JSON body is a bad request
    Given a user with username "user1" exists
    And the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "username": "user1", "firstName": 
      """
    When I send a PUT request to "/user/user1"
    Then the response status code should be 400

  @negative
  Scenario: updateUser - wrong field type is a bad request
    Given a user with username "user1" exists
    And the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "username": "user1", "userStatus": "active" }
      """
    When I send a PUT request to "/user/user1"
    Then the response status code should be 400

  @negative
  Scenario: updateUser - user not found
    Given no user with username "no-such-user-xyz" exists
    And the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "username": "no-such-user-xyz", "firstName": "Nobody" }
      """
    When I send a PUT request to "/user/no-such-user-xyz"
    Then the response status code should be 404

  @contract
  Scenario: updateUser - accepts an XML request body
    Given a user with username "user1" exists
    And the request header "Content-Type" is "application/xml"
    And the request body is:
      """
      <User><username>user1</username><firstName>Xml</firstName></User>
      """
    When I send a PUT request to "/user/user1"
    Then the response status code should be 200

  @contract
  Scenario: updateUser - accepts a form-encoded request body
    Given a user with username "user1" exists
    And the request header "Content-Type" is "application/x-www-form-urlencoded"
    And the request body is:
      """
      username=user1&firstName=Form
      """
    When I send a PUT request to "/user/user1"
    Then the response status code should be 200

  @boundary
  Scenario: updateUser - path and body usernames may differ
    Given a user with username "user1" exists
    And the request header "Content-Type" is "application/json"
    And the request body is:
      """
      { "username": "user1-renamed", "firstName": "Renamed" }
      """
    When I send a PUT request to "/user/user1"
    Then the response status code should be 200
    And a subsequent GET request to "/user/user1-renamed" should return status code 200

  @boundary
  Scenario: updateUser - accepts a minimal body
    Given a user with username "user1" exists
    And the request header "Content-Type" is "application/json"
    And the request body is:
      """
      {}
      """
    When I send a PUT request to "/user/user1"
    Then the response status code should be 200

  @negative
  Scenario: updateUser - rejects an empty request body
    Given a user with username "user1" exists
    And the request header "Content-Type" is "application/json"
    And the request body is empty
    When I send a PUT request to "/user/user1"
    Then the response status code should be 400

  # ---------------------------------------------------------------------------
  # deleteUser - DELETE /user/{username}
  # ---------------------------------------------------------------------------

  Scenario: deleteUser - delete an existing user
    Given a user with username "user2" exists
    When I send a DELETE request to "/user/user2"
    Then the response status code should be 200
    And a subsequent GET request to "/user/user2" should return status code 404

  @negative
  Scenario Outline: deleteUser - invalid username supplied
    When I send a DELETE request to "/user/<username>"
    Then the response status code should be 400

    Examples:
      | username            |
      | %20                 |
      | user%2Fwith%2Fslash |

  @negative
  Scenario: deleteUser - user not found
    Given no user with username "no-such-user-xyz" exists
    When I send a DELETE request to "/user/no-such-user-xyz"
    Then the response status code should be 404

  @boundary
  Scenario: deleteUser - usernames are case-sensitive
    Given a user with username "user1" exists
    When I send a DELETE request to "/user/USER1"
    Then the response status code should be 404

  @boundary
  Scenario: deleteUser - deleting twice returns not found
    Given a user with username "delete-twice" exists
    When I send a DELETE request to "/user/delete-twice"
    Then the response status code should be 200
    And a subsequent DELETE request to "/user/delete-twice" should return status code 404

  @boundary
  Scenario Outline: deleteUser - accepts punctuation in usernames
    Given a user with username "<username>" exists
    When I send a DELETE request to "/user/<username>"
    Then the response status code should be 200
    And a subsequent GET request to "/user/<username>" should return status code 404

    Examples:
      | username   |
      | user.name  |
      | user-name  |
      | user_name  |
