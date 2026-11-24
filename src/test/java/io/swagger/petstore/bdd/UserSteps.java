package io.swagger.petstore.bdd;

import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.restassured.response.Response;

import static org.junit.Assert.assertEquals;

/** User fixtures, payload builders and session login. */
public class UserSteps {

    private final TestContext ctx;

    public UserSteps(final TestContext ctx) {
        this.ctx = ctx;
    }

    @Given("the user {string} exists with password {string}")
    public void userWithPassword(final String username, final String password) {
        createUser(username, password);
    }

    @Given("a user with username {string} exists")
    public void userExists(final String username) {
        createUser(username, "12345");
    }

    @Given("I am logged in as {string} with password {string}")
    public void login(final String username, final String password) {
        final Response r = ctx.fixture("GET", "/user/login?username=" + TestContext.encode(username)
                + "&password=" + TestContext.encode(password), null);
        assertEquals("Login failed: " + r.asString(), 200, r.statusCode());
        final String body = r.asString();
        ctx.headers.put("Authorization", "Bearer " + body.substring(body.lastIndexOf(' ') + 1).replace("\"", ""));
    }

    @Given("a valid user payload with username {string} encoded as {string}")
    public void validUserPayload(final String username, final String contentType) {
        switch (contentType) {
            case "application/xml":
                ctx.setBody("<user><id>1</id><username>" + username + "</username><firstName>John</firstName>"
                        + "<lastName>James</lastName><email>john@email.com</email><password>12345</password>"
                        + "<phone>12345</phone><userStatus>1</userStatus></user>");
                break;
            case "application/x-www-form-urlencoded":
                ctx.setBody("id=1&username=" + TestContext.encode(username) + "&firstName=John&lastName=James"
                        + "&email=" + TestContext.encode("john@email.com") + "&password=12345&phone=12345&userStatus=1");
                break;
            default:
                ctx.setBody(userJson(username, "12345"));
        }
    }

    @Given("a user payload with username {string}")
    public void userPayload(final String username) {
        ctx.setBody(userJson(username, "12345"));
    }

    @Given("a user payload with a username of {int} characters")
    public void userPayloadLongName(final int length) {
        ctx.setBody(userJson(TestContext.repeat('u', length), "12345"));
    }

    @Given("a user list payload with {int} users prefixed {string}")
    public void userList(final int count, final String prefix) {
        final StringBuilder sb = new StringBuilder("[");
        for (int i = 1; i <= count; i++) {
            sb.append(i == 1 ? "" : ",").append(userJson(prefix + i, "12345"));
        }
        ctx.setBody(sb.append(']').toString());
    }

    @Then("the user {string} should exist")
    public void userShouldExist(final String username) {
        assertEquals(200, ctx.fixture("GET", "/user/" + TestContext.encode(username), null).statusCode());
    }

    @Then("the user {string} should not exist")
    public void userShouldNotExist(final String username) {
        assertEquals(404, ctx.fixture("GET", "/user/" + TestContext.encode(username), null).statusCode());
    }

    private void createUser(final String username, final String password) {
        final Response r = ctx.fixture("POST", "/user", userJson(username, password));
        assertEquals("Fixture user creation failed: " + r.asString(), 200, r.statusCode());
    }

    private static String userJson(final String username, final String password) {
        return "{\"id\":1,\"username\":" + TestContext.quote(username) + ",\"firstName\":\"John\",\"lastName\":\"James\""
                + ",\"email\":\"john@email.com\",\"password\":" + TestContext.quote(password)
                + ",\"phone\":\"12345\",\"userStatus\":1}";
    }
}
