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

## Scope

These are functional tests only: they assert on status codes, response
schema/shape, enum values, required fields and auth outcomes. They contain no
performance or response-time assertions.

Step definitions are not included; the steps use a small, consistent vocabulary
(`the request header ... is ...`, `the request body is:`, `I send a <METHOD>
request to ...`, `the response status code should be ...`, `the response body
should match the "<Schema>" schema`, ...) so they can be bound in Cucumber-JVM,
Behave, or any other Gherkin runner.

Note: the spec does not declare a `401` response explicitly (auth failures fall
under `default: Unexpected error`); the `@auth @negative` scenarios assert `401`
as the conventional outcome for a missing or invalid credential.
