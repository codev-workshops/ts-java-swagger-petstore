package io.swagger.petstore.bdd;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.dataformat.yaml.YAMLMapper;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/** Minimal structural validation of JSON responses against components.schemas in openapi.yaml. */
final class SchemaChecker {

    private static final JsonNode SCHEMAS = load();

    private SchemaChecker() {
    }

    static List<String> validate(final JsonNode node, final String schemaName) {
        final List<String> errors = new ArrayList<>();
        check(node, schema(schemaName), "$", errors);
        return errors;
    }

    private static JsonNode schema(final String name) {
        final JsonNode schema = SCHEMAS.get(name);
        if (schema == null) {
            throw new IllegalArgumentException("Unknown schema " + name);
        }
        return schema;
    }

    private static void check(final JsonNode node, JsonNode schema, final String path, final List<String> errors) {
        if (schema.has("$ref")) {
            final String ref = schema.get("$ref").asText();
            schema = schema(ref.substring(ref.lastIndexOf('/') + 1));
        }
        if (node == null || node.isNull()) {
            return;
        }
        final String type = schema.path("type").asText("object");
        switch (type) {
            case "integer":
                if (!node.isIntegralNumber()) {
                    errors.add(path + " should be an integer but was " + node);
                } else if ("int32".equals(schema.path("format").asText()) && !node.canConvertToInt()) {
                    errors.add(path + " exceeds int32: " + node);
                }
                break;
            case "string":
                if (!node.isTextual()) {
                    errors.add(path + " should be a string but was " + node);
                } else if (schema.has("enum")) {
                    boolean found = false;
                    for (final JsonNode allowed : schema.get("enum")) {
                        found |= allowed.asText().equals(node.asText());
                    }
                    if (!found) {
                        errors.add(path + " value " + node + " is not in enum " + schema.get("enum"));
                    }
                }
                break;
            case "boolean":
                if (!node.isBoolean()) {
                    errors.add(path + " should be a boolean but was " + node);
                }
                break;
            case "array":
                if (!node.isArray()) {
                    errors.add(path + " should be an array but was " + node);
                } else {
                    for (int i = 0; i < node.size(); i++) {
                        check(node.get(i), schema.get("items"), path + "[" + i + "]", errors);
                    }
                }
                break;
            default:
                if (!node.isObject()) {
                    errors.add(path + " should be an object but was " + node);
                    return;
                }
                for (final JsonNode required : schema.path("required")) {
                    if (!node.has(required.asText())) {
                        errors.add(path + " is missing required property " + required.asText());
                    }
                }
                final Iterator<Map.Entry<String, JsonNode>> props = schema.path("properties").fields();
                while (props.hasNext()) {
                    final Map.Entry<String, JsonNode> prop = props.next();
                    check(node.get(prop.getKey()), prop.getValue(), path + "." + prop.getKey(), errors);
                }
        }
    }

    private static JsonNode load() {
        try (InputStream in = SchemaChecker.class.getResourceAsStream("/openapi.yaml")) {
            return new YAMLMapper().readTree(in).path("components").path("schemas");
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}
