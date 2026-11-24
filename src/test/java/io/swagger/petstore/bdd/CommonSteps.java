package io.swagger.petstore.bdd;

import com.fasterxml.jackson.databind.JsonNode;
import io.cucumber.java.After;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Set;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

/** Generic HTTP, credential and response-assertion steps. */
public class CommonSteps {

    private final TestContext ctx;

    public CommonSteps(final TestContext ctx) {
        this.ctx = ctx;
    }

    // ---- request setup ------------------------------------------------------------------------

    @Given("the Petstore API base URL is {string}")
    public void baseUrl(final String basePath) {
        ctx.basePath = basePath;
    }

    @Given("the request header {string} is {string}")
    public void header(final String name, final String value) {
        ctx.headers.put(name, value);
    }

    @Given("I am not authenticated")
    public void notAuthenticated() {
        ctx.clearCredentials();
    }

    @Given("I am not logged in")
    public void notLoggedIn() {
        ctx.clearCredentials();
    }

    @Given("I am authorized with an OAuth2 bearer token with scopes {string}")
    public void bearerWithScopes(final String scopes) {
        ctx.headers.put("Authorization", "Bearer test-token:" + scopes);
    }

    @Given("I am authorized with the OAuth2 bearer token {string}")
    public void bearer(final String token) {
        ctx.headers.put("Authorization", "Bearer " + token);
    }

    @Given("I use the session token {string}")
    public void sessionToken(final String token) {
        ctx.headers.put("Authorization", "Bearer " + token);
    }

    @Given("the request body is:")
    public void bodyDocString(final String body) {
        ctx.setBody(body);
    }

    @Given("the request body is {string}")
    public void bodyInline(final String body) {
        ctx.setBody(body);
    }

    @Given("the request body is the binary file {string}")
    public void bodyFile(final String resource) {
        try (InputStream in = getClass().getResourceAsStream("/" + resource)) {
            assertNotNull("Missing test resource " + resource, in);
            final java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
            final byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) {
                out.write(buf, 0, n);
            }
            ctx.body = out.toByteArray();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    @Given("the request body is a binary payload of {int} bytes")
    public void bodyBytes(final int size) {
        ctx.body = new byte[size];
        Arrays.fill(ctx.body, (byte) 0x2A);
    }

    @Given("the query parameter {string} is a string of {int} characters")
    public void longQueryParam(final String name, final int length) {
        ctx.queryOverrides.put(name, TestContext.repeat('q', length));
    }

    @Given("the path parameter {string} is a string of {int} characters")
    public void longPathParam(final String name, final int length) {
        ctx.pathOverrides.put(name, TestContext.repeat('p', length));
    }

    @Given("the resource at {string} is deleted after the scenario")
    public void cleanupAfter(final String path) {
        final io.restassured.response.Response existing = ctx.fixture("GET", path, null);
        ctx.cleanupPaths.put(path, existing.statusCode() == 200 ? existing.asString() : null);
    }

    /** Deletes resources a scenario created and restores any pre-existing (seeded) resource at that path. */
    @After
    public void cleanup() {
        for (final java.util.Map.Entry<String, String> entry : ctx.cleanupPaths.entrySet()) {
            final String path = entry.getKey();
            ctx.fixture("DELETE", path, null);
            if (entry.getValue() != null) {
                ctx.fixture("POST", path.substring(0, path.lastIndexOf('/')), entry.getValue());
            }
        }
    }

    // ---- requests -----------------------------------------------------------------------------

    @When("I send a {word} request to {string}")
    public void send(final String method, final String path) {
        ctx.send(method, path, null, false);
    }

    @When("I send a {word} request to {string} with content type {string}")
    public void sendWithBody(final String method, final String path, final String contentType) {
        ctx.send(method, path, contentType, true);
    }

    @When("I send a {word} request to {string} with content type {string} and no body")
    public void sendWithoutBody(final String method, final String path, final String contentType) {
        ctx.send(method, path, contentType, false);
    }

    @When("I store the response body as {string}")
    public void storeBody(final String key) {
        ctx.stored.put(key, ctx.response.asString());
    }

    // ---- status, headers, raw body ------------------------------------------------------------

    @Then("the response status code should be {int}")
    public void status(final int expected) {
        assertEquals("Unexpected status. Body: " + ctx.response.asString(), expected, ctx.response.statusCode());
    }

    @Then("the response status code should be one of {string}")
    public void statusOneOf(final String expected) {
        final Set<Integer> allowed = new HashSet<>();
        for (final String code : expected.split(",")) {
            allowed.add(Integer.parseInt(code.trim()));
        }
        assertTrue("Status " + ctx.response.statusCode() + " not in " + allowed + ". Body: " + ctx.response.asString(),
                allowed.contains(ctx.response.statusCode()));
    }

    @Then("the response content type should be {string}")
    public void contentType(final String expected) {
        final String actual = ctx.response.contentType();
        assertTrue("Content type was " + actual, actual != null && actual.startsWith(expected));
    }

    @Then("the response body should contain {string}")
    public void bodyContains(final String text) {
        assertTrue("Body was: " + ctx.response.asString(), ctx.response.asString().contains(text));
    }

    @Then("the response body should not contain {string}")
    public void bodyNotContains(final String text) {
        assertFalse("Body was: " + ctx.response.asString(), ctx.response.asString().contains(text));
    }

    @Then("the response body should not equal the stored value {string}")
    public void bodyNotEqualStored(final String key) {
        assertNotEquals(ctx.stored.get(key), ctx.response.asString());
    }

    @Then("the response header {string} should be an int32")
    public void headerInt32(final String name) {
        final String value = ctx.response.header(name);
        assertNotNull("Missing header " + name, value);
        Integer.parseInt(value.trim());
    }

    @Then("the response header {string} should be a date in the future")
    public void headerFutureDate(final String name) {
        final String value = ctx.response.header(name);
        assertNotNull("Missing header " + name, value);
        try {
            assertTrue(name + " is not in the future: " + value, OffsetDateTime.parse(value).isAfter(OffsetDateTime.now()));
        } catch (DateTimeParseException e) {
            fail(name + " is not an RFC 3339 date-time as the spec requires: " + value);
        }
    }

    @Then("the response should not contain a {string} header")
    public void noHeader(final String name) {
        assertNull(name + " header present", ctx.response.header(name));
    }

    // ---- JSON body ----------------------------------------------------------------------------

    @Then("the response body should match the {string} schema")
    public void matchesSchema(final String schema) {
        final List<String> errors = SchemaChecker.validate(ctx.json(), schema);
        assertTrue("Schema violations: " + errors, errors.isEmpty());
    }

    @Then("the response body should be an array of {string} schema items")
    public void arrayOfSchema(final String schema) {
        final JsonNode body = ctx.json();
        assertTrue("Body is not an array: " + body, body.isArray());
        for (final JsonNode item : body) {
            final List<String> errors = SchemaChecker.validate(item, schema);
            assertTrue("Schema violations: " + errors, errors.isEmpty());
        }
    }

    @Then("the response body should be an empty array")
    public void emptyArray() {
        final JsonNode body = ctx.json();
        assertTrue("Expected empty array: " + body, body.isArray() && body.size() == 0);
    }

    @Then("the response body should be a map of string keys to int32 values")
    public void mapOfInt32() {
        final JsonNode body = ctx.json();
        assertTrue("Body is not an object: " + body, body.isObject());
        for (final JsonNode value : body) {
            assertTrue("Not an int32: " + value, value.isIntegralNumber() && value.canConvertToInt());
        }
    }

    @Then("every value in the response map should be greater than or equal to {int}")
    public void mapValuesAtLeast(final int min) {
        for (final JsonNode value : ctx.json()) {
            assertTrue("Value below " + min + ": " + value, value.asLong() >= min);
        }
    }

    @Then("every item in the response should have {string} equal to {string}")
    public void everyItemFieldEquals(final String field, final String expected) {
        for (final JsonNode item : ctx.json()) {
            assertEquals(item.toString(), expected, item.path(field).asText());
        }
    }

    @Then("every item in the response should have {string} in {string}")
    public void everyItemFieldIn(final String field, final String allowed) {
        final List<String> values = Arrays.asList(allowed.split(","));
        for (final JsonNode item : ctx.json()) {
            assertTrue(item.toString(), values.contains(item.path(field).asText()));
        }
    }

    @Then("every item in the response should have a tag named {string}")
    public void everyItemHasTag(final String tag) {
        everyItemHasTagIn(tag);
    }

    @Then("every item in the response should have at least one tag in {string}")
    public void everyItemHasTagIn(final String tags) {
        final List<String> wanted = Arrays.asList(tags.split(","));
        final JsonNode body = ctx.json();
        assertTrue("Expected at least one pet: " + body, body.size() > 0);
        for (final JsonNode item : body) {
            boolean found = false;
            for (final JsonNode tag : item.path("tags")) {
                found |= wanted.contains(tag.path("name").asText());
            }
            assertTrue("Pet has none of " + wanted + ": " + item, found);
        }
    }

    @Then("the response field {string} should equal {string}")
    public void fieldEqualsString(final String field, final String expected) {
        assertEquals(expected, field(field).asText());
    }

    @Then("^the response field \"([^\"]*)\" should equal (-?\\d+|true|false)$")
    public void fieldEqualsLiteral(final String field, final String expected) {
        assertEquals(expected, field(field).asText());
    }

    @Then("the response field {string} should be an empty array")
    public void fieldEmptyArray(final String field) {
        final JsonNode node = field(field);
        assertTrue(field + " = " + node, node.isArray() && node.size() == 0);
    }

    @Then("the response field {string} should have {int} items")
    public void fieldItems(final String field, final int count) {
        assertEquals(count, field(field).size());
    }

    @Then("the response field {string} should have length {int}")
    public void fieldLength(final String field, final int length) {
        assertEquals(length, field(field).asText().length());
    }

    @Then("the response field {string} should be absent or masked")
    public void fieldAbsentOrMasked(final String field) {
        final JsonNode node = ctx.json().get(field);
        assertTrue(field + " exposed: " + node, node == null || node.isNull() || node.asText().matches("[*X]*"));
    }

    private JsonNode field(final String path) {
        JsonNode node = ctx.json();
        final Iterator<String> parts = Arrays.asList(path.split("\\.")).iterator();
        while (parts.hasNext()) {
            node = node.path(parts.next());
        }
        assertFalse("Missing field " + path + " in " + ctx.response.asString(), node.isMissingNode());
        return node;
    }
}
