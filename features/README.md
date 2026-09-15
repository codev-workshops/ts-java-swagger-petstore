# Gherkin feature files

These `.feature` files were derived from `src/main/resources/openapi.yaml`
(Swagger Petstore - OpenAPI 3.0, version 1.0.27). Every operation in the spec is
covered, grouped one file per tag:

| File | Tag | Operations |
| --- | --- | --- |
| `pet.feature` | `pet` | `updatePet`, `addPet`, `findPetsByStatus`, `findPetsByTags`, `getPetById`, `updatePetWithForm`, `deletePet`, `uploadFile`, `listPetPhotos` |
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

## PR coverage check

`.github/workflows/api-coverage.yml` runs on every pull request (`opened`,
`synchronize`, `reopened`) and executes `scripts/check_endpoint_coverage.py`,
which:

1. enumerates every `(METHOD, PATH)` operation under `paths:` in
   `src/main/resources/openapi.yaml`;
2. scans `features/*.feature` for request steps and maps each one back to a
   spec operation;
3. fails (exit 1) and lists the endpoints that no scenario exercises.

When a gap is found the workflow posts/updates a PR comment with the uncovered
endpoints and starts a Devin session (`POST /v3/organizations/{org_id}/sessions` on the Devin API) that
is asked to add the missing scenarios to `features/`, reusing the step
vocabulary and the `@auth` / `@negative` / `@boundary` tags described above, and
to open a PR against the branch under review.

Run the check locally with `python scripts/check_endpoint_coverage.py`
(requires `pyyaml`).

### The request-step convention the analyzer relies on

Every scenario **must** call its endpoint with a step of exactly this shape:

```gherkin
When I send a <METHOD> request to "<path>"
```

for example `When I send a POST request to "/pet"` or
`When I send a GET request to "/pet/10"`. The analyzer:

- strips query strings (`/pet/findByStatus?status=available` -> `/pet/findByStatus`);
- matches concrete or `Scenario Outline` placeholder segments (`/pet/10`,
  `/pet/<petId>`) against templated spec segments (`/pet/{petId}`), preferring a
  literal spec path when one exists (`/pet/findByStatus` is not treated as
  `/pet/{petId}`);
- ignores any request step whose method/path does not resolve to a spec
  operation (these are listed separately in the report).

Steps written in any other form are **not** counted as coverage.

### Required secret and variables

| Name | Type | Purpose |
| --- | --- | --- |
| `DEVIN_API_KEY2` | repository secret (required) | Devin API service-user key (`cog_...`) for the target organization, used as the bearer token. |
| `DEVIN_ORG_ID` | repository variable (required) | Devin organization to create sessions in (`org-...`); pins the org explicitly instead of inferring it from the key. |
| `DEVIN_API_BASE_URL` | repository variable (optional) | Devin API base URL; defaults to `https://api.devin.ai`. For this org's enterprise instance set it to `https://codev.devinenterprise.com/api`. |

Without `DEVIN_API_KEY2`/`DEVIN_ORG_ID` the coverage report and PR comment still run, but the
"Start Devin session" step fails.

Note: the spec does not declare a `401` response explicitly (auth failures fall
under `default: Unexpected error`); the `@auth @negative` scenarios assert `401`
as the conventional outcome for a missing or invalid credential.
