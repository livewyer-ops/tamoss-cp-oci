POST {{issuer}}/application/o/token/
[FormParams]
grant_type: client_credentials
client_id: {{client_id}}
client_secret: {{tadoss_client_secret}}
scope: openid profile tads-api/read
HTTP 200
[Captures]
read_token: jsonpath "$.access_token"

GET {{tads}}/tracks/{{track_id}}
Authorization: Bearer {{read_token}}
HTTP 200
[Asserts]
jsonpath "$.timeline_reference.entity_id" == "{{entity}}"

GET {{tads}}/tracks/{{track_id}}/events
Authorization: Bearer {{read_token}}
[QueryStringParams]
timerange: {{timerange}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].payload.text" == "Metadata for the ingested media segment"
