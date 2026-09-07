package io.swagger.petstore.bdd;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.cucumber.java.AfterAll;
import io.cucumber.java.BeforeAll;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

public class StoreAddressSteps {

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final Set<String> ADDRESS_FIELDS =
            new HashSet<>(Arrays.asList("id", "street", "city", "state", "zipCode", "country"));

    private int status;
    private String contentType;
    private String body;
    private String accept = "application/json";

    @BeforeAll
    public static void startServer() throws Exception {
        PetstoreServer.start();
    }

    @AfterAll
    public static void stopServer() throws Exception {
        PetstoreServer.stop();
    }

    @Given("the petstore API is running")
    public void thePetstoreApiIsRunning() {
        assertNotNull("embedded petstore server is not running", PetstoreServer.baseUrl());
    }

    @Given("I accept {string} responses")
    public void iAcceptResponses(final String mediaType) {
        accept = mediaType;
    }

    @Given("a store address exists with id {long}")
    public void aStoreAddressExistsWithId(final long id) throws IOException {
        final String json = "{\"id\":" + id + ",\"street\":\"437 Lytton\",\"city\":\"Palo Alto\","
                + "\"state\":\"CA\",\"zipCode\":\"94301\",\"country\":\"USA\"}";
        final Response response = call("POST", "/store/address", json, "application/json", "application/json");
        assertEquals("failed to seed address " + id, 200, response.status);
    }

    @Given("no store address exists with id {long}")
    public void noStoreAddressExistsWithId(final long id) throws IOException {
        call("DELETE", "/store/address/" + id, null, null, "application/json");
        final Response response = call("GET", "/store/address/" + id, null, null, "application/json");
        assertEquals("address " + id + " should not exist", 404, response.status);
    }

    @When("I send a {word} request to {string}")
    public void iSendARequestTo(final String method, final String path) throws IOException {
        record(call(method, path, null, null, accept));
    }

    @When("I send a {word} request to {string} with an empty body")
    public void iSendARequestToWithAnEmptyBody(final String method, final String path) throws IOException {
        record(call(method, path, "", "application/json", accept));
    }

    @When("I send a {word} request to {string} with body:")
    public void iSendARequestToWithBody(final String method, final String path, final String json) throws IOException {
        record(call(method, path, json, "application/json", accept));
    }

    @When("I send a {word} request to {string} with XML body:")
    public void iSendARequestToWithXmlBody(final String method, final String path, final String xml) throws IOException {
        record(call(method, path, xml, "application/xml", accept));
    }

    @Then("the response status should be {int}")
    public void theResponseStatusShouldBe(final int expected) {
        assertEquals("unexpected status, body was: " + body, expected, status);
    }

    @Then("the response content type should be {string}")
    public void theResponseContentTypeShouldBe(final String expected) {
        assertNotNull("response has no Content-Type", contentType);
        assertTrue("expected content type " + expected + " but was " + contentType, contentType.startsWith(expected));
    }

    @Then("the response body should be a valid Address")
    public void theResponseBodyShouldBeAValidAddress() throws IOException {
        final JsonNode node = json();
        assertTrue("Address must be a JSON object", node.isObject());
        assertTrue("Address.id must be an integer", node.path("id").isIntegralNumber());
        for (final String field : Arrays.asList("street", "city", "state", "zipCode", "country")) {
            assertTrue("Address." + field + " must be a string", node.path(field).isTextual());
        }
        for (final Iterator<String> it = node.fieldNames(); it.hasNext(); ) {
            final String field = it.next();
            assertTrue("unexpected Address field: " + field, ADDRESS_FIELDS.contains(field));
        }
    }

    @Then("the response body should be an Address with:")
    public void theResponseBodyShouldBeAnAddressWith(final Map<String, String> expected) throws IOException {
        final JsonNode node = json();
        for (final Map.Entry<String, String> entry : expected.entrySet()) {
            assertEquals("Address." + entry.getKey(), entry.getValue(), node.path(entry.getKey()).asText());
        }
    }

    @Then("the response body should be XML with root element {string}")
    public void theResponseBodyShouldBeXmlWithRootElement(final String root) {
        assertTrue("expected XML with root <" + root + "> but body was: " + body,
                body.trim().replaceFirst("^<\\?xml[^>]*\\?>\\s*", "").startsWith("<" + root));
    }

    @Then("the response body should be {string}")
    public void theResponseBodyShouldBe(final String expected) {
        assertEquals(expected, body.trim());
    }

    @Then("the response body should not be empty")
    public void theResponseBodyShouldNotBeEmpty() {
        assertFalse("response body is empty", body.trim().isEmpty());
    }

    @Then("a GET request to {string} should return status {int}")
    public void aGetRequestToShouldReturnStatus(final String path, final int expected) throws IOException {
        record(call("GET", path, null, null, "application/json"));
        assertEquals(expected, status);
    }

    private JsonNode json() throws IOException {
        return MAPPER.readTree(body);
    }

    private void record(final Response response) {
        status = response.status;
        contentType = response.contentType;
        body = response.body;
    }

    private static Response call(final String method, final String path, final String payload,
                                 final String payloadType, final String accept) throws IOException {
        final HttpURLConnection connection =
                (HttpURLConnection) new URL(PetstoreServer.baseUrl() + path).openConnection();
        connection.setRequestMethod(method);
        connection.setRequestProperty("Accept", accept);
        if (payload != null) {
            connection.setDoOutput(true);
            connection.setRequestProperty("Content-Type", payloadType);
            try (OutputStream out = connection.getOutputStream()) {
                out.write(payload.getBytes(StandardCharsets.UTF_8));
            }
        }
        final int code = connection.getResponseCode();
        final InputStream stream = code >= 400 ? connection.getErrorStream() : connection.getInputStream();
        return new Response(code, connection.getContentType(), read(stream));
    }

    private static String read(final InputStream stream) throws IOException {
        if (stream == null) {
            return "";
        }
        try (InputStream in = stream) {
            final ByteArrayOutputStream buffer = new ByteArrayOutputStream();
            final byte[] chunk = new byte[4096];
            int n;
            while ((n = in.read(chunk)) != -1) {
                buffer.write(chunk, 0, n);
            }
            return new String(buffer.toByteArray(), StandardCharsets.UTF_8);
        }
    }

    private static final class Response {
        private final int status;
        private final String contentType;
        private final String body;

        private Response(final int status, final String contentType, final String body) {
            this.status = status;
            this.contentType = contentType;
            this.body = body;
        }
    }
}
