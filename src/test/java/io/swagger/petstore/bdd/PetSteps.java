package io.swagger.petstore.bdd;

import com.fasterxml.jackson.databind.JsonNode;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.restassured.response.Response;

import java.io.IOException;

import static org.junit.Assert.assertEquals;

/** Pet fixtures and payload builders. */
public class PetSteps {

    private final TestContext ctx;

    public PetSteps(final TestContext ctx) {
        this.ctx = ctx;
    }

    @Given("a pet with id {long} and name {string} exists")
    public void petExists(final long id, final String name) {
        createPet(id, name, "available");
    }

    @Given("a pet with id {long}, name {string} and status {string} exists")
    public void petWithStatusExists(final long id, final String name, final String status) {
        createPet(id, name, status);
    }

    @Given("no pet with id {long} exists")
    public void noPet(final long id) {
        ctx.restoreAfterScenario("/pet/" + id);
        ctx.fixture("DELETE", "/pet/" + id, null);
        assertEquals(404, ctx.fixture("GET", "/pet/" + id, null).statusCode());
    }

    @Given("no pet has status {string}")
    public void noPetWithStatus(final String status) throws IOException {
        final Response found = ctx.fixture("GET", "/pet/findByStatus?status=" + status, null);
        for (final JsonNode pet : TestContext.JSON.readTree(found.asByteArray())) {
            ctx.restoreAfterScenario("/pet/" + pet.path("id").asText());
            ctx.fixture("DELETE", "/pet/" + pet.path("id").asText(), null);
        }
    }

    @Given("^a valid pet payload with id (-?[\\d.]+) and name \"([^\"]*)\" encoded as \"([^\"]*)\"$")
    public void validPetPayload(final String id, final String name, final String contentType) {
        ctx.setBody(encodePet(id, name, contentType));
    }

    @Given("a pet payload with id {long} and a name of {int} characters")
    public void petWithNameLength(final long id, final int length) {
        ctx.setBody(petJson(String.valueOf(id), TestContext.repeat('n', length), "available"));
    }

    @Given("a pet payload with id {long}, {int} photo URLs and {int} tags")
    public void petWithManyItems(final long id, final int urls, final int tags) {
        final StringBuilder sb = new StringBuilder("{\"id\":").append(id).append(",\"name\":\"many\",\"photoUrls\":[");
        for (int i = 0; i < urls; i++) {
            sb.append(i == 0 ? "" : ",").append("\"https://example.com/").append(i).append(".png\"");
        }
        sb.append("],\"tags\":[");
        for (int i = 0; i < tags; i++) {
            sb.append(i == 0 ? "" : ",").append("{\"id\":").append(i).append(",\"name\":\"t").append(i).append("\"}");
        }
        ctx.setBody(sb.append("]}").toString());
    }

    @Then("a pet with id {long} should still exist")
    public void petStillExists(final long id) {
        assertEquals(200, ctx.fixture("GET", "/pet/" + id, null).statusCode());
    }

    private void createPet(final long id, final String name, final String status) {
        ctx.restoreAfterScenario("/pet/" + id);
        final Response r = ctx.fixture("POST", "/pet", petJson(String.valueOf(id), name, status));
        assertEquals("Fixture pet creation failed: " + r.asString(), 200, r.statusCode());
    }

    static String petJson(final String id, final String name, final String status) {
        return "{\"id\":" + id + ",\"name\":" + TestContext.quote(name)
                + ",\"category\":{\"id\":1,\"name\":\"Dogs\"},\"photoUrls\":[\"https://example.com/pet.png\"]"
                + ",\"tags\":[{\"id\":1,\"name\":\"tag1\"}],\"status\":\"" + status + "\"}";
    }

    private static String encodePet(final String id, final String name, final String contentType) {
        switch (contentType) {
            case "application/xml":
                return "<pet><id>" + id + "</id><name>" + name + "</name>"
                        + "<category><id>1</id><name>Dogs</name></category>"
                        + "<photoUrls><photoUrl>https://example.com/pet.png</photoUrl></photoUrls>"
                        + "<tags><tag><id>1</id><name>tag1</name></tag></tags><status>available</status></pet>";
            case "application/x-www-form-urlencoded":
                return "id=" + id + "&name=" + TestContext.encode(name)
                        + "&photoUrls=" + TestContext.encode("https://example.com/pet.png") + "&status=available";
            default:
                return petJson(id, name, "available");
        }
    }
}
