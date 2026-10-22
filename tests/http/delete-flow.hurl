DELETE {{api}}/flows/{{flow}}
Authorization: Bearer {{token}}
HTTP *
[Asserts]
status toString matches "^(202|204|404)$"

GET {{api}}/flows/{{flow}}
Authorization: Bearer {{token}}
[Options]
retry: 90
retry-interval: 2000ms
HTTP 404
