package io.swagger.petstore.bdd;

import com.fasterxml.jackson.databind.JsonNode;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.restassured.response.Response;

import java.io.IOException;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

/** Order and inventory fixtures. */
public class StoreSteps {

    private final TestContext ctx;

    public StoreSteps(final TestContext ctx) {
        this.ctx = ctx;
    }

    @Given("a valid order payload with id {long} and petId {long} encoded as {string}")
    public void validOrderPayload(final long id, final long petId, final String contentType) {
        switch (contentType) {
            case "application/xml":
                ctx.setBody("<order><id>" + id + "</id><petId>" + petId + "</petId><quantity>1</quantity>"
                        + "<status>placed</status><complete>false</complete></order>");
                break;
            case "application/x-www-form-urlencoded":
                ctx.setBody("id=" + id + "&petId=" + petId + "&quantity=1&status=placed&complete=false");
                break;
            default:
                ctx.setBody(orderJson(id, petId, "placed", 1));
        }
    }

    @Given("an order with id {long} and petId {long} exists")
    public void orderExists(final long id, final long petId) {
        createOrder(id, petId, "placed", 1);
    }

    @Given("an order with id {long}, status {string} and quantity {int} exists")
    public void orderWithStatusExists(final long id, final String status, final int quantity) {
        createOrder(id, 1, status, quantity);
    }

    @Given("orders with ids {string} exist")
    public void ordersExist(final String ids) {
        for (final String id : ids.split(",")) {
            createOrder(Long.parseLong(id.trim()), 1, "placed", 1);
        }
    }

    @Given("no order with id {long} exists")
    public void noOrder(final long id) {
        ctx.fixture("DELETE", "/store/order/" + id, null);
        assertEquals(404, ctx.fixture("GET", "/store/order/" + id, null).statusCode());
    }

    @Given("I record the inventory count for status {string}")
    public void recordInventory(final String status) throws IOException {
        ctx.recordedInventory.put(status, inventoryCount(status));
    }

    @Then("the inventory count for status {string} should have increased by {int}")
    public void inventoryIncreased(final String status, final int delta) throws IOException {
        assertEquals(ctx.recordedInventory.get(status) + delta, inventoryCount(status));
    }

    @Then("the inventory count for status {string} should be {int} or absent")
    public void inventoryZeroOrAbsent(final String status, final int expected) {
        final JsonNode count = ctx.json().get(status);
        assertTrue(status + " = " + count, count == null || count.asInt() == expected);
    }

    private int inventoryCount(final String status) throws IOException {
        final Response r = ctx.fixture("GET", "/store/inventory", null);
        return TestContext.JSON.readTree(r.asByteArray()).path(status).asInt(0);
    }

    private void createOrder(final long id, final long petId, final String status, final int quantity) {
        final Response r = ctx.fixture("POST", "/store/order", orderJson(id, petId, status, quantity));
        assertEquals("Fixture order creation failed: " + r.asString(), 200, r.statusCode());
    }

    private static String orderJson(final long id, final long petId, final String status, final int quantity) {
        return "{\"id\":" + id + ",\"petId\":" + petId + ",\"quantity\":" + quantity
                + ",\"shipDate\":\"2026-12-01T10:00:00.000Z\",\"status\":\"" + status + "\",\"complete\":false}";
    }
}
