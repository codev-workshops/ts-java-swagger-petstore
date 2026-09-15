import datetime as dt
import os
from pathlib import Path
from urllib.parse import urljoin

import jsonschema
import requests
import yaml
from behave import given, then, when
from behave.matchers import use_step_matcher
from parse_type import TypeBuilder


use_step_matcher("parse")
from behave import register_type

register_type(Boolean=TypeBuilder.make_enum({"true": True, "false": False}))
ROOT = Path(__file__).resolve().parents[2]
SPEC = yaml.safe_load((ROOT / "src/main/resources/openapi.yaml").read_text())
SCHEMAS = SPEC["components"]["schemas"]


def _schema(name):
    return SCHEMAS[name]


def _validate(value, name):
    resolver = jsonschema.RefResolver.from_schema(SPEC)
    jsonschema.validate(value, _schema(name), resolver=resolver)


def _url(context, path):
    return urljoin(context.base_url.rstrip("/") + "/", path.lstrip("/"))


def _header(context, name, value):
    if name.lower() == "api_key" and value == "special-key":
        return os.getenv("PETSTORE_API_KEY", "special-key")
    return value


def _pop_header(context, name):
    for key in list(context.headers):
        if key.lower() == name.lower():
            context.headers.pop(key)


def _json(context):
    try:
        return context.response.json()
    except ValueError as exc:
        raise AssertionError(
            f"response was not JSON: {context.response.text[:300]}"
        ) from exc


def _field(value, name):
    for part in name.split("."):
        value = value[part]
    return value


def _value(text):
    text = str(text).strip()
    if len(text) >= 2 and text[0] == text[-1] == '"':
        return text[1:-1]
    if text.lower() == "true":
        return True
    if text.lower() == "false":
        return False
    try:
        return int(text)
    except ValueError:
        return text


def _is_datetime(value):
    try:
        dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        return True
    except ValueError:
        return False


def _send(context, method, path):
    context.response = requests.request(
        method, _url(context, path), headers=context.headers,
        data=context.body, timeout=20
    )


def _best_effort(context, method, path, payload=None):
    try:
        headers = dict(context.headers)
        if payload is not None:
            headers.setdefault("Content-Type", "application/json")
        requests.request(
            method,
            _url(context, path),
            headers=headers,
            json=payload,
            timeout=10,
        )
    except requests.RequestException:
        pass


def _pet(pet_id):
    return {
        "id": pet_id, "name": f"pet-{pet_id}",
        "photoUrls": [f"https://example.com/{pet_id}.jpg"],
        "status": "available",
    }


def _user(username, password=None):
    return {
        "id": 11, "username": username, "firstName": "Test",
        "lastName": "User", "email": f"{username}@example.com",
        "password": password or username, "phone": "555-0100", "userStatus": 1,
    }


def _order(order_id):
    return {
        "id": order_id, "petId": 198772, "quantity": 1,
        "shipDate": "2026-09-15T09:00:00.000Z",
        "status": "placed", "complete": False,
    }


@given('the API base URL is "{url}"')
def set_base_url(context, url):
    context.base_url = os.getenv("PETSTORE_BASE_URL", url)


@given('the request header "{name}" is "{value}"')
def set_header(context, name, value):
    context.headers[name] = _header(context, name, value)


@given('I hold a valid "{scheme}" OAuth2 token with scopes')
def set_oauth_token(context, scheme):
    token = os.getenv("PETSTORE_OAUTH_TOKEN", "behave-placeholder-token")
    context.headers["Authorization"] = f"Bearer {token}"


@given('I do not send any Authorization header')
def remove_authorization(context):
    _pop_header(context, "Authorization")


@given('I do not send an "{name}" header')
def remove_header(context, name):
    _pop_header(context, name)


@given("the request body is")
def set_body(context):
    context.body = context.text


@given('the request body is the binary contents of file "{filename}"')
def set_binary_body(context, filename):
    context.body = (ROOT / "features" / filename).read_bytes()


@given("the request body is empty")
def set_empty_body(context):
    context.body = b""


@given("a pet with id {pet_id:d} exists")
def ensure_pet(context, pet_id):
    _best_effort(context, "POST", "/pet", _pet(pet_id))


@given("no pet with id {pet_id:d} exists")
def remove_pet(context, pet_id):
    _best_effort(context, "DELETE", f"/pet/{pet_id}")


@given("an order with id {order_id:d} exists")
def ensure_order(context, order_id):
    _best_effort(context, "POST", "/store/order", _order(order_id))


@given("no order with id {order_id:d} exists")
def remove_order(context, order_id):
    _best_effort(context, "DELETE", f"/store/order/{order_id}")


@given('a user with username "{username}" exists')
def ensure_user(context, username):
    _best_effort(context, "POST", "/user", _user(username))


@given("a user exists with credentials")
def ensure_user_credentials(context):
    row = context.table[0]
    _best_effort(context, "POST", "/user", _user(row["username"], row["password"]))


@given('no user with username "{username}" exists')
def remove_user(context, username):
    _best_effort(context, "DELETE", f"/user/{username}")


@given('I am logged in as "{username}"')
def login_user(context, username):
    _best_effort(context, "GET", f"/user/login?username={username}&password={username}")


@when('I send a {method} request to "{path}"')
def send_request(context, method, path):
    _send(context, method, path)


@then("the response status code should be {status:d}")
def response_status(context, status):
    assert context.response.status_code == status, (
        f"expected {status}, got {context.response.status_code}: "
        f"{context.response.text[:300]}"
    )


@then('the response body should match the "{name}" schema')
def response_schema(context, name):
    _validate(_json(context), name)


@then("the response body should be a JSON array")
def response_array(context):
    assert isinstance(_json(context), list)


@then("the response body should be a JSON object")
def response_object(context):
    assert isinstance(_json(context), dict)


@then("the response body should be a string")
def response_string(context):
    assert isinstance(_json(context), str)


@then("the response body should contain the required fields")
def required_fields(context):
    body = _json(context)
    for row in context.table:
        assert row["field"] in body


@then("the response body should contain the fields")
def typed_fields(context):
    body = _json(context)
    for row in context.table:
        value = body[row["field"]]
        expected = row["type"]
        assert (
            (expected == "string" and isinstance(value, str))
            or (expected == "integer" and isinstance(value, int) and not isinstance(value, bool))
            or (expected == "boolean" and isinstance(value, bool))
            or (expected == "array" and isinstance(value, list))
            or (expected == "object" and isinstance(value, dict))
        ), f"{row['field']} is not a {expected}"


@then('the response field "{name}" should be "{expected}"')
def string_field(context, name, expected):
    assert _field(_json(context), name) == expected


@then('the response field "{name}" should be one of "{values}"')
def enum_field(context, name, values):
    assert _field(_json(context), name) in [item.strip() for item in values.split(",")]


@then('the response field "{name}" should be {expected:d}')
def integer_value_field(context, name, expected):
    assert _field(_json(context), name) == expected


@then('the response field "{name}" should be {expected:Boolean}')
def boolean_value_field(context, name, expected):
    assert _field(_json(context), name) is expected


@then('the response field "{name}" should contain "{text}"')
def contains_field(context, name, text):
    assert text in _field(_json(context), name)


@then('the response field "{name}" should have {count:d} items')
def count_field(context, name, count):
    assert len(_field(_json(context), name)) == count


@then('the response field "{name}" should be an array of strings')
def string_array_field(context, name):
    assert all(isinstance(item, str) for item in _field(_json(context), name))


@then('the response field "{name}" should be an array of "{schema}" objects')
def object_array_field(context, name, schema):
    for item in _field(_json(context), name):
        _validate(item, schema)


@then('the response field "{name}" should be an integer')
def integer_field(context, name):
    value = _field(_json(context), name)
    assert isinstance(value, int) and not isinstance(value, bool)


@then('the response field "{name}" should be a boolean')
def boolean_field(context, name):
    assert isinstance(_field(_json(context), name), bool)


@then('the response field "{name}" should be a string')
def string_type_field(context, name):
    assert isinstance(_field(_json(context), name), str)


@then('the response field "{name}" should be a date-time string')
def datetime_field(context, name):
    value = _field(_json(context), name)
    assert isinstance(value, str) and _is_datetime(value)


@then("every item in the response array should match the \"{schema}\" schema")
def array_schema(context, schema):
    for item in _json(context):
        _validate(item, schema)


@then('every item in the response array should have field "{name}" equal to "{expected}"')
def array_string_field(context, name, expected):
    for item in _json(context):
        assert _field(item, name) == expected


@then('every item in the response array should have a tag named "{tag}"')
def array_tag(context, tag):
    for item in _json(context):
        assert any(t.get("name") == tag for t in item.get("tags", []))


@then("every key in the response object should be a string")
def object_keys(context):
    assert all(isinstance(key, str) for key in _json(context))


@then("every value in the response object should be an int32 integer")
def object_values(context):
    assert all(
        isinstance(value, int) and not isinstance(value, bool) and -(2**31) <= value < 2**31
        for value in _json(context).values()
    )


@then('the response header "{name}" should be present')
def header_present(context, name):
    assert name in context.response.headers


@then('the response header "{name}" should be an int32 integer')
def header_integer(context, name):
    value = context.response.headers[name]
    assert -(2**31) <= int(value) < 2**31


@then('the response header "{name}" should be a date-time string')
def header_datetime(context, name):
    assert _is_datetime(context.response.headers[name])


@then('a subsequent GET request to "{path}" should return status code {status:d}')
def subsequent_status(context, path, status):
    _send(context, "GET", path)
    response_status(context, status)


@then('a subsequent GET request to "{path}" should return field "{name}" equal to "{expected}"')
def subsequent_string_field(context, path, name, expected):
    _send(context, "GET", path)
    assert _field(_json(context), name) == expected


@then("a subsequent GET request to \"{path}\" should return field \"{name}\" equal to {expected}")
def subsequent_scalar_field(context, path, name, expected):
    _send(context, "GET", path)
    assert _field(_json(context), name) == _value(expected)
