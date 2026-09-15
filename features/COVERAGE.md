# BDD operation coverage

| Operation | Method+Path | Happy | Negative | Auth | Boundary | Contract |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| updatePet | PUT /pet | 1 | 7 | 2 | 2 | 2 |
| addPet | POST /pet | 2 | 6 | 2 | 6 | 2 |
| findPetsByStatus | GET /pet/findByStatus | 2 | 2 | 1 | 1 | 0 |
| findPetsByTags | GET /pet/findByTags | 2 | 3 | 1 | 2 | 0 |
| getPetById | GET /pet/{petId} | 1 | 4 | 2 | 2 | 0 |
| updatePetWithForm | POST /pet/{petId} | 2 | 3 | 1 | 3 | 0 |
| deletePet | DELETE /pet/{petId} | 2 | 3 | 1 | 3 | 0 |
| uploadFile | POST /pet/{petId}/uploadImage | 2 | 4 | 1 | 4 | 0 |
| getInventory | GET /store/inventory | 0 | 3 | 3 | 1 | 0 |
| placeOrder | POST /store/order | 2 | 6 | 0 | 7 | 2 |
| getOrderById | GET /store/order/{orderId} | 1 | 4 | 0 | 4 | 0 |
| deleteOrder | DELETE /store/order/{orderId} | 1 | 4 | 0 | 5 | 0 |
| createUser | POST /user | 1 | 5 | 0 | 6 | 2 |
| createUsersWithListInput | POST /user/createWithList | 1 | 2 | 0 | 3 | 0 |
| loginUser | GET /user/login | 1 | 2 | 0 | 3 | 0 |
| logoutUser | GET /user/logout | 2 | 1 | 0 | 2 | 0 |
| getUserByName | GET /user/{username} | 1 | 2 | 0 | 3 | 0 |
| updateUser | PUT /user/{username} | 1 | 4 | 0 | 2 | 2 |
| deleteUser | DELETE /user/{username} | 1 | 2 | 0 | 3 | 0 |

Counts above are scenario counts, computed from the feature tags after the
coverage additions.

## Gaps found and filled

- No operation lacked scenarios.
- Happy-path-only before this change: `logoutUser`, `getInventory`
  (auth-only negatives).
- The declared XML and form-urlencoded content types on five operations had
  zero scenarios.
- Boundary categories added for integer limits, empty/minimal payloads, string
  lengths, unicode, repeated parameters, and idempotence.

`createUsersWithArrayInput` exists in `UserController` but has no route in
`openapi.yaml`, so it is intentionally not covered.
