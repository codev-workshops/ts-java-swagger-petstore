package io.swagger.petstore.bdd;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.xml.XmlMapper;
import io.restassured.RestAssured;
import io.restassured.config.EncoderConfig;
import io.restassured.config.RestAssuredConfig;
import io.restassured.http.ContentType;
import io.restassured.response.Response;
import io.restassured.specification.RequestSpecification;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

/** Per-scenario request/response state shared by all step classes (injected by PicoContainer). */
public class TestContext {

    static final ObjectMapper JSON = new ObjectMapper();
    private static final ObjectMapper XML = new XmlMapper();

    private static final RestAssuredConfig CONFIG = RestAssuredConfig.config()
            .encoderConfig(EncoderConfig.encoderConfig()
                    .appendDefaultContentCharsetToContentTypeIfUndefined(false)
                    .encodeContentTypeAs("application/x-www-form-urlencoded", ContentType.TEXT)
                    .encodeContentTypeAs("application/octet-stream", ContentType.BINARY)
                    .encodeContentTypeAs("multipart/form-data", ContentType.BINARY)
                    .encodeContentTypeAs("text/plain", ContentType.TEXT));

    private static final String FIXTURE_AUTHORIZATION = "Bearer fixture-token:write:pets,read:pets";
    private static final String FIXTURE_API_KEY = "special-key";

    String basePath = "/api/v3";
    final Map<String, String> headers = new LinkedHashMap<>();
    final Map<String, String> queryOverrides = new LinkedHashMap<>();
    final Map<String, String> pathOverrides = new LinkedHashMap<>();
    final Map<String, String> stored = new HashMap<>();
    final Map<String, Integer> recordedInventory = new HashMap<>();
    byte[] body;
    Response response;
    final Map<String, String> cleanupPaths = new LinkedHashMap<>();

    void clearCredentials() {
        headers.remove("Authorization");
        headers.remove("api_key");
    }

    void setBody(final String text) {
        body = text.getBytes(StandardCharsets.UTF_8);
    }

    Response send(final String method, final String path, final String contentType, final boolean withBody) {
        final RequestSpecification spec = RestAssured.given().config(CONFIG).urlEncodingEnabled(false)
                .headers(headers);
        if (contentType != null) {
            spec.contentType(contentType);
        }
        if (withBody && body != null) {
            spec.body(body);
        }
        response = spec.request(method, url(path));
        return response;
    }

    /** Fixture setup/inspection that must not depend on the scenario's credentials or headers. */
    Response fixture(final String method, final String path, final String json) {
        final RequestSpecification spec = RestAssured.given().config(CONFIG).urlEncodingEnabled(false)
                .header("Authorization", FIXTURE_AUTHORIZATION)
                .header("api_key", FIXTURE_API_KEY)
                .accept("application/json");
        if (json != null) {
            spec.contentType("application/json").body(json);
        }
        return spec.request(method, PetstoreServer.baseUrl() + basePath + path);
    }

    String url(final String path) {
        String resolved = path;
        for (final Map.Entry<String, String> e : pathOverrides.entrySet()) {
            resolved = resolved.replace("{" + e.getKey() + "}", encode(e.getValue()));
        }
        final StringBuilder url = new StringBuilder(PetstoreServer.baseUrl()).append(basePath).append(resolved);
        for (final Map.Entry<String, String> e : queryOverrides.entrySet()) {
            url.append(url.indexOf("?") < 0 ? '?' : '&').append(e.getKey()).append('=').append(encode(e.getValue()));
        }
        return url.toString();
    }

    JsonNode json() {
        try {
            final String type = response.contentType();
            final ObjectMapper mapper = type != null && type.contains("xml") ? XML : JSON;
            return mapper.readTree(response.asByteArray());
        } catch (IOException e) {
            throw new AssertionError("Response is not JSON: " + response.asString(), e);
        }
    }

    static String encode(final String value) {
        try {
            return URLEncoder.encode(value, "UTF-8").replace("+", "%20");
        } catch (UnsupportedEncodingException e) {
            throw new UncheckedIOException(e);
        }
    }

    static String quote(final String value) {
        try {
            return JSON.writeValueAsString(value);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    static String repeat(final char c, final int count) {
        final StringBuilder sb = new StringBuilder(count);
        for (int i = 0; i < count; i++) {
            sb.append(c);
        }
        return sb.toString();
    }
}
