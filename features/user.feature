@user
Feature: User resource
  As a Petstore API client
  I want to register, log in, look up, update and remove users
  So that customers can manage their accounts

  Endpoints covered (src/main/resources/openapi.yaml, tag "user"):
    POST   /user                    createUser
    POST   /user/createWithList     createUsersWithListInput
    GET    /user/login              loginUser
    GET    /user/logout             logoutUser
    GET    /user/{username}         getUserByName
    PUT    /user/{username}         updateUser
    DELETE /user/{username}         deleteUser

  The spec declares no security scheme for user operations, but createUser,
  updateUser and deleteUser are documented as "This can only be done by the
  logged in user". Scenarios tagged @auth therefore use the session token
  returned by GET /user/login and expect 401 when it is missing or invalid.
  Seed data provides users "user1" .. "user10" and "user?10" without passwords,
  so the Background assigns known passwords to the accounts used for login.

  Scenarios tagged @known-gap fail against the current server and are excluded from
  `mvn test`; the @gap-* tag names the missing behavior. Run them with
  -Dcucumber.filter.tags="@known-gap".

  Background:
    Given the Petstore API base URL is "/api/v3"
    And the request header "Accept" is "application/json"
    And the user "user1" exists with password "s3cret-Pa55"
    And the user "user?10" exists with password "s3cret-Pa55"

  # ---------------------------------------------------------------------------
  # POST /user  (createUser)
  # ---------------------------------------------------------------------------

  @createUser @positive
  Scenario: Create a user with all fields
    Given I am logged in as "user1" with password "s3cret-Pa55"
    And the request body is:
      """
      {
        "id": 1001,
        "username": "newuser1001",
        "firstName": "John",
        "lastName": "James",
        "email": "john@email.com",
        "password": "12345",
        "phone": "12345",
        "userStatus": 1
      }
      """
    When I send a POST request to "/user" with content type "application/json"
    Then the response status code should be 200
    And the response body should match the "User" schema
    And the response field "username" should equal "newuser1001"
    When I send a GET request to "/user/newuser1001"
    Then the response status code should be 200
    And the response field "email" should equal "john@email.com"

  @createUser @positive
  Scenario Outline: Create a user using the "<contentType>" request format
    Given I am logged in as "user1" with password "s3cret-Pa55"
    And a valid user payload with username "<username>" encoded as "<contentType>"
    When I send a POST request to "/user" with content type "<contentType>"
    Then the response status code should be 200
    And the response field "username" should equal "<username>"

    Examples:
      | contentType                       | username     |
      | application/json                  | json-user    |
      | application/xml                   | xml-user     |
      | application/x-www-form-urlencoded | form-user    |

  @createUser @positive
  Scenario: Create a user with only a username
    Given I am logged in as "user1" with password "s3cret-Pa55"
    And the request body is:
      """
      { "username": "minimal-user" }
      """
    When I send a POST request to "/user" with content type "application/json"
    Then the response status code should be 200
    And the response field "username" should equal "minimal-user"

  @createUser @negative
  Scenario: Reject creating a user with an empty request body
    Given I am logged in as "user1" with password "s3cret-Pa55"
    When I send a POST request to "/user" with content type "application/json" and no body
    Then the response status code should be 400

  @createUser @negative
  Scenario: Reject creating a user with malformed JSON
    Given I am logged in as "user1" with password "s3cret-Pa55"
    And the request body is:
      """
      { "username": "broken",
      """
    When I send a POST request to "/user" with content type "application/json"
    Then the response status code should be 400

  @createUser @negative
  Scenario Outline: Reject creating a user with an invalid field type
    Given the resource at "/user/12345" is deleted after the scenario
    And I am logged in as "user1" with password "s3cret-Pa55"
    And the request body is:
      """
      <body>
      """
    When I send a POST request to "/user" with content type "application/json"
    Then the response status code should be one of "400,422"

    Examples:
      | description           | body                                              |
      | id is a string        | { "id": "abc", "username": "bad-id" }             |
      | userStatus is string  | { "username": "bad-status", "userStatus": "one" } |
      | body is a JSON array  | [ { "username": "array-user" } ]                  |

    @known-gap @gap-input-validation
    Examples: known gaps
      | description           | body                                              |
      | username is a number  | { "username": 12345 }                             |

  @createUser @negative
  Scenario: Reject creating a user with an unsupported content type
    Given I am logged in as "user1" with password "s3cret-Pa55"
    And the request body is "username=plain-user"
    When I send a POST request to "/user" with content type "text/plain"
    Then the response status code should be 415

  @createUser @auth @known-gap @gap-auth
  Scenario: Reject creating a user when not logged in
    Given I am not logged in
    And a valid user payload with username "anon-created" encoded as "application/json"
    When I send a POST request to "/user" with content type "application/json"
    Then the response status code should be 401

  @createUser @auth @known-gap @gap-auth
  Scenario: Reject creating a user with an invalid session token
    Given I use the session token "invalid-session-token"
    And a valid user payload with username "bad-session-created" encoded as "application/json"
    When I send a POST request to "/user" with content type "application/json"
    Then the response status code should be 401

  @createUser @boundary
  Scenario Outline: Create a user with boundary id and userStatus values
    Given I am logged in as "user1" with password "s3cret-Pa55"
    And the request body is:
      """
      { "id": <id>, "username": "<username>", "userStatus": <userStatus> }
      """
    When I send a POST request to "/user" with content type "application/json"
    Then the response status code should be <code>

    Examples:
      | description              | id                  | username     | userStatus  | code |
      | zero values              | 0                   | zero-user    | 0           | 200  |
      | int64 max id             | 9223372036854775807 | max-id-user  | 1           | 200  |
      | int64 id overflow        | 9223372036854775808 | overflow-id  | 1           | 400  |
      | int32 max userStatus     | 1002                | max-status   | 2147483647  | 200  |
      | int32 userStatus overflow| 1003                | over-status  | 2147483648  | 400  |
      | negative userStatus      | 1004                | neg-status   | -1          | 200  |

  @createUser @boundary
  Scenario Outline: Create a user with boundary username values
    Given I am logged in as "user1" with password "s3cret-Pa55"
    And a user payload with username "<username>"
    When I send a POST request to "/user" with content type "application/json"
    Then the response status code should be one of "<codes>"

    Examples:
      | description                | username          | codes   |
      | empty username             |                   | 200,400 |
      | single character           | a                 | 200     |
      | unicode                    | usér-名前          | 200     |
      | path-sensitive characters  | user/with/slashes | 200,400 |
      | query-sensitive characters | user?q=1          | 200     |

  @createUser @boundary
  Scenario: Create a user with a very long username
    Given I am logged in as "user1" with password "s3cret-Pa55"
    And a user payload with a username of 1000 characters
    When I send a POST request to "/user" with content type "application/json"
    Then the response status code should be one of "200,400"

  @createUser @boundary
  Scenario: Creating a user with an existing username is handled deterministically
    Given I am logged in as "user1" with password "s3cret-Pa55"
    And the request body is:
      """
      { "id": 1005, "username": "user2", "firstName": "Duplicate" }
      """
    When I send a POST request to "/user" with content type "application/json"
    Then the response status code should be one of "200,400,409"
    When I send a GET request to "/user/user2"
    Then the response status code should be 200

  # ---------------------------------------------------------------------------
  # POST /user/createWithList  (createUsersWithListInput)
  # ---------------------------------------------------------------------------

  @createUsersWithListInput @positive
  Scenario: Create multiple users from a list
    Given the request body is:
      """
      [
        { "id": 2001, "username": "list-user-1", "email": "l1@email.com" },
        { "id": 2002, "username": "list-user-2", "email": "l2@email.com" }
      ]
      """
    When I send a POST request to "/user/createWithList" with content type "application/json"
    Then the response status code should be 200
    When I send a GET request to "/user/list-user-1"
    Then the response status code should be 200
    When I send a GET request to "/user/list-user-2"
    Then the response status code should be 200

  @createUsersWithListInput @negative
  Scenario: Reject an empty user list
    Given the request body is:
      """
      []
      """
    When I send a POST request to "/user/createWithList" with content type "application/json"
    Then the response status code should be 400
    And the response body should contain "No User provided"

  @createUsersWithListInput @negative
  Scenario: Reject a missing request body
    When I send a POST request to "/user/createWithList" with content type "application/json" and no body
    Then the response status code should be 400

  @createUsersWithListInput @negative
  Scenario Outline: Reject an invalid user list payload
    Given the request body is:
      """
      <body>
      """
    When I send a POST request to "/user/createWithList" with content type "application/json"
    Then the response status code should be one of "400,422"

    Examples:
      | description            | body                                     |
      | single object not list | { "id": 2003, "username": "not-a-list" } |
      | item with bad id type  | [ { "id": "abc", "username": "bad" } ]   |
      | list of strings        | [ "user-a", "user-b" ]                   |
      | malformed JSON         | [ { "username": "broken" }               |

  @createUsersWithListInput @negative
  Scenario: Reject a user list sent as XML (only application/json is accepted)
    Given the request body is:
      """
      <users><user><username>xml-list</username></user></users>
      """
    When I send a POST request to "/user/createWithList" with content type "application/xml"
    Then the response status code should be 415

  @createUsersWithListInput @auth
  Scenario: Create users from a list without credentials (no security defined)
    Given I am not logged in
    And the request body is:
      """
      [ { "id": 2004, "username": "anon-list-user" } ]
      """
    When I send a POST request to "/user/createWithList" with content type "application/json"
    Then the response status code should be 200

  @createUsersWithListInput @auth
  Scenario: An invalid session token does not block creating users from a list
    Given I use the session token "invalid-session-token"
    And the request body is:
      """
      [ { "id": 2005, "username": "bad-session-list-user" } ]
      """
    When I send a POST request to "/user/createWithList" with content type "application/json"
    Then the response status code should be 200

  @createUsersWithListInput @boundary
  Scenario Outline: Create user lists of boundary sizes
    Given a user list payload with <count> users prefixed "bulk-<count>-"
    When I send a POST request to "/user/createWithList" with content type "application/json"
    Then the response status code should be 200
    And the user "bulk-<count>-<count>" should exist

    Examples:
      | count |
      | 1     |
      | 100   |
      | 1000  |

  @createUsersWithListInput @boundary
  Scenario: Create a user list containing duplicate usernames
    Given the request body is:
      """
      [
        { "id": 2006, "username": "dup-in-list", "firstName": "First" },
        { "id": 2007, "username": "dup-in-list", "firstName": "Second" }
      ]
      """
    When I send a POST request to "/user/createWithList" with content type "application/json"
    Then the response status code should be one of "200,400,409"
    When I send a GET request to "/user/dup-in-list"
    Then the response status code should be 200

  # ---------------------------------------------------------------------------
  # GET /user/login  (loginUser)
  # ---------------------------------------------------------------------------

  @loginUser @positive
  Scenario: Log in with valid credentials
    When I send a GET request to "/user/login?username=user1&password=s3cret-Pa55"
    Then the response status code should be 200
    And the response body should contain "Logged in user session"
    And the response header "X-Rate-Limit" should be an int32

  @loginUser @positive @known-gap @gap-response-format
  Scenario: Login returns X-Expires-After as an RFC 3339 date-time
    When I send a GET request to "/user/login?username=user1&password=s3cret-Pa55"
    Then the response status code should be 200
    And the response header "X-Expires-After" should be a date in the future

  @loginUser @positive
  Scenario Outline: Log in and receive the session in the "<accept>" format
    Given the request header "Accept" is "<accept>"
    When I send a GET request to "/user/login?username=user1&password=s3cret-Pa55"
    Then the response status code should be 200
    And the response content type should be "<accept>"

    Examples:
      | accept           |
      | application/json |
      | application/xml  |

  @loginUser @positive
  Scenario: Each login returns a new session token
    When I send a GET request to "/user/login?username=user1&password=s3cret-Pa55"
    And I store the response body as "firstSession"
    And I send a GET request to "/user/login?username=user1&password=s3cret-Pa55"
    Then the response body should not equal the stored value "firstSession"

  @loginUser @negative
  Scenario Outline: Reject login with missing parameters
    When I send a GET request to "/user/login<query>"
    Then the response status code should be 400

    @known-gap @gap-login-validation
    Examples:
      | description       | query                 |
      | no parameters     |                       |
      | only username     | ?username=user1       |
      | only password     | ?password=s3cret-Pa55 |

  @loginUser @auth
  Scenario Outline: Reject login with invalid credentials
    When I send a GET request to "/user/login?username=<username>&password=<password>"
    Then the response status code should be 400
    And the response should not contain a "X-Expires-After" header

    @known-gap @gap-login-validation
    Examples:
      | description         | username       | password       |
      | wrong password      | user1          | wrong-password |
      | unknown user        | no-such-user   | s3cret-Pa55    |
      | wrong-case username | USER1          | s3cret-Pa55    |
      | empty password      | user1          |                |
      | empty username      |                | s3cret-Pa55    |

  @loginUser @auth
  Scenario: Login does not leak the password in the response
    When I send a GET request to "/user/login?username=user1&password=s3cret-Pa55"
    Then the response status code should be 200
    And the response body should not contain "s3cret-Pa55"

  @loginUser @boundary
  Scenario Outline: Log in with boundary credential values
    When I send a GET request to "/user/login?username=<username>&password=<password>"
    Then the response status code should be one of "<codes>"

    Examples:
      | description                   | username             | password             | codes   |
      | username needs url-encoding   | user%3F10            | s3cret-Pa55          | 200     |

    @known-gap @gap-login-validation
    Examples: known gaps
      | description                   | username             | password             | codes   |
      | sql injection attempt         | user1'%20OR%20'1'='1 | x                    | 400     |
      | encoded unicode password      | user1                | %F0%9F%94%91         | 400     |
      | password with spaces          | user1                | %20s3cret-Pa55%20    | 400     |

  @loginUser @boundary @known-gap @gap-login-validation
  Scenario: Log in with a very long username and password
    Given the query parameter "username" is a string of 1000 characters
    And the query parameter "password" is a string of 1000 characters
    When I send a GET request to "/user/login"
    Then the response status code should be 400

  # ---------------------------------------------------------------------------
  # GET /user/logout  (logoutUser)
  # ---------------------------------------------------------------------------

  @logoutUser @positive
  Scenario: Log out a logged-in user
    Given I am logged in as "user1" with password "s3cret-Pa55"
    When I send a GET request to "/user/logout"
    Then the response status code should be 200
    And the response body should contain "User logged out"

  @logoutUser @positive @known-gap @gap-auth
  Scenario: Session token is no longer accepted after logout
    Given I am logged in as "user1" with password "s3cret-Pa55"
    And I send a GET request to "/user/logout"
    And a valid user payload with username "after-logout" encoded as "application/json"
    When I send a POST request to "/user" with content type "application/json"
    Then the response status code should be 401

  @logoutUser @negative
  Scenario Outline: Logout rejects unsupported HTTP methods
    Given I am logged in as "user1" with password "s3cret-Pa55"
    When I send a <method> request to "/user/logout"
    Then the response status code should be 405

    # DELETE is omitted: DELETE /user/logout is DELETE /user/{username} with username "logout".
    Examples:
      | method |
      | POST   |

  @logoutUser @auth
  Scenario: Log out without a session is a harmless no-op
    Given I am not logged in
    When I send a GET request to "/user/logout"
    Then the response status code should be 200

  @logoutUser @auth
  Scenario: Log out with an invalid session token is a harmless no-op
    Given I use the session token "invalid-session-token"
    When I send a GET request to "/user/logout"
    Then the response status code should be 200

  @logoutUser @boundary
  Scenario: Logging out twice in a row
    Given I am logged in as "user1" with password "s3cret-Pa55"
    When I send a GET request to "/user/logout"
    Then the response status code should be 200
    When I send a GET request to "/user/logout"
    Then the response status code should be 200

  @logoutUser @boundary
  Scenario: Logout ignores unexpected query parameters
    Given I am logged in as "user1" with password "s3cret-Pa55"
    When I send a GET request to "/user/logout?username=user2"
    Then the response status code should be 200

  # ---------------------------------------------------------------------------
  # GET /user/{username}  (getUserByName)
  # ---------------------------------------------------------------------------

  @getUserByName @positive
  Scenario: Get a seeded user by username
    When I send a GET request to "/user/user1"
    Then the response status code should be 200
    And the response body should match the "User" schema
    And the response field "username" should equal "user1"

  @getUserByName @positive
  Scenario Outline: Get a user in the "<accept>" format
    Given the request header "Accept" is "<accept>"
    When I send a GET request to "/user/user1"
    Then the response status code should be 200
    And the response content type should be "<accept>"

    Examples:
      | accept           |
      | application/json |
      | application/xml  |

  @getUserByName @negative
  Scenario: Get a user that does not exist returns 404
    When I send a GET request to "/user/no-such-user"
    Then the response status code should be 404
    And the response body should contain "User not found"

  @getUserByName @negative
  Scenario: Get a user without a username in the path
    When I send a GET request to "/user/"
    Then the response status code should be one of "400,404,405"

  @getUserByName @auth
  Scenario: Get a user without credentials (no security defined)
    Given I am not logged in
    When I send a GET request to "/user/user1"
    Then the response status code should be 200

  @getUserByName @auth @known-gap @gap-password-exposed
  Scenario: User lookup does not expose the password
    When I send a GET request to "/user/user1"
    Then the response status code should be 200
    And the response field "password" should be absent or masked

  @getUserByName @boundary
  Scenario Outline: Get a user with boundary username values
    When I send a GET request to "/user/<username>"
    Then the response status code should be <code>

    Examples:
      | description                  | username   | code |
      | url-encoded special char     | user%3F10  | 200  |
      | wrong case                   | USER1      | 404  |
      | numeric-looking username     | 12345      | 404  |
      | encoded whitespace           | %20        | 404  |
      | encoded path traversal       | ..%2Fpet   | 404  |

  @getUserByName @boundary
  Scenario: Get a user with a very long username
    Given the path parameter "username" is a string of 1000 characters
    When I send a GET request to "/user/{username}"
    Then the response status code should be one of "400,404,414"

  # ---------------------------------------------------------------------------
  # PUT /user/{username}  (updateUser)
  # ---------------------------------------------------------------------------

  @updateUser @positive
  Scenario: Update an existing user
    Given a user with username "update-me" exists
    And I am logged in as "update-me" with password "12345"
    And the request body is:
      """
      {
        "id": 3001,
        "username": "update-me",
        "firstName": "Updated",
        "lastName": "Name",
        "email": "updated@email.com",
        "password": "12345",
        "phone": "67890",
        "userStatus": 2
      }
      """
    When I send a PUT request to "/user/update-me" with content type "application/json"
    Then the response status code should be 200
    When I send a GET request to "/user/update-me"
    Then the response field "firstName" should equal "Updated"
    And the response field "email" should equal "updated@email.com"

  @updateUser @positive
  Scenario: Rename a user via update
    Given a user with username "old-name" exists
    And I am logged in as "old-name" with password "12345"
    And the request body is:
      """
      { "id": 3002, "username": "new-name" }
      """
    When I send a PUT request to "/user/old-name" with content type "application/json"
    Then the response status code should be 200
    When I send a GET request to "/user/new-name"
    Then the response status code should be 200
    When I send a GET request to "/user/old-name"
    Then the response status code should be 404

  @updateUser @positive
  Scenario Outline: Update a user using the "<contentType>" request format
    Given a user with username "fmt-update" exists
    And I am logged in as "fmt-update" with password "12345"
    And a valid user payload with username "fmt-update" encoded as "<contentType>"
    When I send a PUT request to "/user/fmt-update" with content type "<contentType>"
    Then the response status code should be 200

    Examples:
      | contentType                       |
      | application/json                  |
      | application/xml                   |

    @known-gap @gap-server-error
    Examples: known gaps
      | contentType                       |
      | application/x-www-form-urlencoded |

  @updateUser @negative
  Scenario: Updating a user that does not exist returns 404
    Given I am logged in as "user1" with password "s3cret-Pa55"
    And a valid user payload with username "ghost-user" encoded as "application/json"
    When I send a PUT request to "/user/ghost-user" with content type "application/json"
    Then the response status code should be 404
    And the response body should contain "User not found"

  @updateUser @negative
  Scenario: Reject updating a user with an empty request body
    Given a user with username "empty-update" exists
    And I am logged in as "empty-update" with password "12345"
    When I send a PUT request to "/user/empty-update" with content type "application/json" and no body
    Then the response status code should be 400

  @updateUser @negative
  Scenario Outline: Reject updating a user with an invalid payload
    Given a user with username "invalid-update" exists
    And I am logged in as "invalid-update" with password "12345"
    And the request body is:
      """
      <body>
      """
    When I send a PUT request to "/user/invalid-update" with content type "application/json"
    Then the response status code should be one of "400,422"

    Examples:
      | description          | body                                                    |
      | id is a string       | { "id": "abc", "username": "invalid-update" }           |
      | userStatus is string | { "username": "invalid-update", "userStatus": "one" }   |
      | malformed JSON       | { "username": "invalid-update",                         |

  @updateUser @auth @known-gap @gap-auth
  Scenario: Reject updating a user when not logged in
    Given a user with username "protected-user" exists
    And I am not logged in
    And a valid user payload with username "protected-user" encoded as "application/json"
    When I send a PUT request to "/user/protected-user" with content type "application/json"
    Then the response status code should be 401

  @updateUser @auth @known-gap @gap-auth
  Scenario: Reject updating a user with an invalid session token
    Given a user with username "protected-user-2" exists
    And I use the session token "invalid-session-token"
    And a valid user payload with username "protected-user-2" encoded as "application/json"
    When I send a PUT request to "/user/protected-user-2" with content type "application/json"
    Then the response status code should be 401

  @updateUser @auth @known-gap @gap-auth
  Scenario: Reject updating a different user's account
    Given a user with username "victim-user" exists
    And I am logged in as "user1" with password "s3cret-Pa55"
    And a valid user payload with username "victim-user" encoded as "application/json"
    When I send a PUT request to "/user/victim-user" with content type "application/json"
    Then the response status code should be 403

  @updateUser @boundary
  Scenario Outline: Update a user with boundary field values
    Given a user with username "boundary-update" exists
    And I am logged in as "boundary-update" with password "12345"
    And the request body is:
      """
      { "username": "boundary-update", "userStatus": <userStatus>, "email": "<email>" }
      """
    When I send a PUT request to "/user/boundary-update" with content type "application/json"
    Then the response status code should be <code>

    Examples:
      | description           | userStatus  | email            | code |
      | int32 max userStatus  | 2147483647  | a@b.co           | 200  |
      | int32 min userStatus  | -2147483648 | a@b.co           | 200  |
      | int32 overflow        | 2147483648  | a@b.co           | 400  |
      | empty email           | 1           |                  | 200  |
      | unicode email         | 1           | usér@exämple.com | 200  |

  @updateUser @boundary
  Scenario: Update a user whose username needs URL encoding
    Given I am logged in as "user?10" with password "s3cret-Pa55"
    And a valid user payload with username "user?10" encoded as "application/json"
    When I send a PUT request to "/user/user%3F10" with content type "application/json"
    Then the response status code should be 200

  # ---------------------------------------------------------------------------
  # DELETE /user/{username}  (deleteUser)
  # ---------------------------------------------------------------------------

  @deleteUser @positive
  Scenario: Delete an existing user
    Given a user with username "delete-me" exists
    And I am logged in as "delete-me" with password "12345"
    When I send a DELETE request to "/user/delete-me"
    Then the response status code should be 200
    When I send a GET request to "/user/delete-me"
    Then the response status code should be 404

  @deleteUser @negative
  Scenario: Deleting a user that does not exist
    Given I am logged in as "user1" with password "s3cret-Pa55"
    When I send a DELETE request to "/user/no-such-user"
    Then the response status code should be one of "200,404"

  @deleteUser @negative
  Scenario: Delete without a username in the path
    Given I am logged in as "user1" with password "s3cret-Pa55"
    When I send a DELETE request to "/user/"
    Then the response status code should be one of "400,404,405"

  @deleteUser @auth @known-gap @gap-auth
  Scenario: Reject deleting a user when not logged in
    Given a user with username "keep-me" exists
    And I am not logged in
    When I send a DELETE request to "/user/keep-me"
    Then the response status code should be 401
    And the user "keep-me" should exist

  @deleteUser @auth @known-gap @gap-auth
  Scenario: Reject deleting a user with an invalid session token
    Given a user with username "keep-me-2" exists
    And I use the session token "invalid-session-token"
    When I send a DELETE request to "/user/keep-me-2"
    Then the response status code should be 401
    And the user "keep-me-2" should exist

  @deleteUser @auth @known-gap @gap-auth
  Scenario: Reject deleting a different user's account
    Given a user with username "keep-me-3" exists
    And I am logged in as "user1" with password "s3cret-Pa55"
    When I send a DELETE request to "/user/keep-me-3"
    Then the response status code should be 403
    And the user "keep-me-3" should exist

  @deleteUser @boundary
  Scenario Outline: Delete users with boundary username values
    Given a user with username "<username>" exists
    And I am logged in as "<username>" with password "12345"
    When I send a DELETE request to "/user/<encoded>"
    Then the response status code should be 200
    And the user "<username>" should not exist

    Examples:
      | description              | username  | encoded         |
      | single character         | z         | z               |
      | needs url-encoding       | del?user  | del%3Fuser      |
      | contains spaces          | del user  | del%20user      |
      | unicode                  | dél-ユーザー | d%C3%A9l-%E3%83%A6%E3%83%BC%E3%82%B6%E3%83%BC |

  @deleteUser @boundary
  Scenario: Deleting the same user twice
    Given a user with username "delete-twice" exists
    And I am logged in as "delete-twice" with password "12345"
    When I send a DELETE request to "/user/delete-twice"
    Then the response status code should be 200
    When I send a DELETE request to "/user/delete-twice"
    Then the response status code should be one of "200,404"
