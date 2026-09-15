# Gherkin feature files

These `.feature` files were derived from `src/main/resources/openapi.yaml`
(Swagger Petstore - OpenAPI 3.0, version 1.0.27). Every operation in the spec is
covered, grouped one file per tag:

| File | Tag | Operations |
| --- | --- | --- |
| `pet.feature` | `pet` | `updatePet`, `addPet`, `findPetsByStatus`, `findPetsByTags`, `getPetById`, `updatePetWithForm`, `deletePet`, `uploadFile` |
| `store.feature` | `store` | `getInventory`, `placeOrder`, `getOrderById`, `deleteOrder` |
| `user.feature` | `user` | `createUser`, `createUsersWithListInput`, `loginUser`, `logoutUser`, `getUserByName`, `updateUser`, `deleteUser` |

Base server URL: `https://petstore3.swagger.io/api/v3` (set in each `Background`).

## Conventions

- `Scenario` for single cases; `Scenario Outline` + `Examples` for enum,
  status-code and boundary variation.
- Data Tables for flat scalar fields; Doc Strings for nested JSON bodies
  (`Pet`, `Order`, `User`).
- Tags, so runs can be filtered:
  - `@auth` – scenarios exercising `petstore_auth` (OAuth2) or `api_key` security.
  - `@negative` – scenarios expecting an error status (400/401/404/422).
  - `@boundary` – scenarios around the ID limits described in the spec
    (`getOrderById`: ids `<= 5` or `> 10` are valid; `deleteOrder`: ids `< 1000` are valid).

## Running against a live Petstore

Install the Python test dependencies from the repository root:

```console
pip install -r features/requirements.txt
```

Run every feature against the public demo server:

```console
behave features/
```

Tags can be used to focus a run or omit expected-error cases:

```console
behave --tags=@auth
behave --tags=~@negative
```

The runner supports these environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `PETSTORE_BASE_URL` | URL in each `Background` | Override the API base URL |
| `PETSTORE_OAUTH_TOKEN` | `behave-placeholder-token` | Bearer token for `petstore_auth` steps |
| `PETSTORE_API_KEY` | `special-key` | Value sent by `api_key` steps |

To run against a local server, start it in another terminal:

```console
mvn package jetty:run
```

Jetty listens on port `8080`; point Behave at the local API prefix:

```console
PETSTORE_BASE_URL=http://localhost:8080/api/v3 behave features/
```

The public demo server is permissive and may not enforce every declared
security or validation rule. Consequently, some `@negative` and `@auth`
scenarios are expected to fail there; use a local server when checking the
full contract.

Note: the spec does not declare a `401` response explicitly (auth failures fall
under `default: Unexpected error`); the `@auth @negative` scenarios assert `401`
as the conventional outcome for a missing or invalid credential.
