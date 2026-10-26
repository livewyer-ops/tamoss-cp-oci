GET {{tams}}/sources/{{source_id}}
Authorization: Bearer {{token}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{source_id}}"

GET {{tads}}/tracks
HTTP 401

POST {{issuer}}/application/o/token/
[FormParams]
grant_type: client_credentials
client_id: {{client_id}}
client_secret: {{tadoss_client_secret}}
scope: openid profile tads-api/read
HTTP 200
[Captures]
read_token: jsonpath "$.access_token"

PUT {{tads}}/schemas/{{schema_id}}
Authorization: Bearer {{read_token}}
Content-Type: application/json
{"id":"{{schema_id}}","label":"Denied write","schema":{"type":"object"}}
HTTP 403

POST {{issuer}}/application/o/token/
[FormParams]
grant_type: client_credentials
client_id: {{client_id}}
client_secret: {{tadoss_client_secret}}
scope: openid profile tads-api/read tads-api/write tads-api/delete
HTTP 200
[Captures]
write_token: jsonpath "$.access_token"

PUT {{tads}}/schemas/{{schema_id}}
Authorization: Bearer {{write_token}}
Content-Type: application/json
{"id":"{{schema_id}}","label":"Qualification payload","schema":{"type":"object","required":["text"],"properties":{"text":{"type":"string"}},"additionalProperties":false}}
HTTP *
[Asserts]
status >= 200
status < 300

PUT {{tads}}/tracks/{{track_id}}
Authorization: Bearer {{write_token}}
Content-Type: application/json
{"id":"{{track_id}}","schema_id":"{{schema_id}}","label":"TAMS ingest qualification","timeline_reference":{"entity_id":"{{entity}}"}}
HTTP *
[Asserts]
status >= 200
status < 300

POST {{tads}}/tracks/{{track_id}}/events
Authorization: Bearer {{write_token}}
Content-Type: application/json
[{"timerange":"{{timerange}}","payload":{"text":"Metadata for the ingested media segment"}}]
HTTP *
[Asserts]
status >= 200
status < 300
jsonpath "$.all_successful" == true

GET {{tads}}/tracks
Authorization: Bearer {{read_token}}
[QueryStringParams]
timeline_reference.entity_id: {{entity_filter}}
HTTP 200
[Asserts]
jsonpath "$[*].id" includes "{{track_id}}"

GET {{tads}}/tracks/{{track_id}}/events
Authorization: Bearer {{read_token}}
[QueryStringParams]
timerange: {{timerange}}
HTTP 200
[Asserts]
jsonpath "$[*].payload.text" includes "Metadata for the ingested media segment"

GET {{tams}}/flows/{{flow_id}}/segments
Authorization: Bearer {{token}}
[QueryStringParams]
timerange: {{timerange}}
HTTP 200
[Asserts]
jsonpath "$" count > 0
