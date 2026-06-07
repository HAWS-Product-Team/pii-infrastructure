# Story 4 AWS API Gateway mocks HATEOAS APIs

Create a public regional REST API Gateway with mock integrations so our webdevs can build a client.  Building a client
is out of scope for Story 4.  Identity token is out of scope for Story 4. The API Gateway
should be built in its own Terraform module, terraform/api-gateway.  API Gateway will serve 
from the path `/api/v1/`.
The client should only need to know the initial `/welcome` endpoint. All subsequent actions should be discoverable through HATEOAS links returned by the API.
PII in this context means personal inflation index.


## Link format

Each link object should include:

- `rel`
- `href`
- `method`
- optional `title`
- optional `type`

# Graphical interface flow
- Welcome
Server returns the upload link. Client discovers first action.

- Establish Purchase History
Client posts file. Server responds with status link. (It's out of scope to add the session token to the header at this time.
and it's out of scope for unaccepted files to be uploaded.)

- PII Report Status
Client polls status endpoint. Server returns progress and eventual summary link.

- PII Report Summary
Server returns PII (CPI category links are out of scope for this story.).

# Endpoints
The following endpoints all start from the same domain and path of `/api/v1/`.  So Get /welcome would have the path of:
`<domain>/api/v1/welcome`.

## GET /welcome
Returns the first available action.

Response will be:
HTTP 200
type: application/json
```json
{
  "message": "Money is an important resource we all care about. We can help you get insight as to how it's being used.",
  "title" : "Personal Inflation Index",
  "links": [           
    {
      "rel": "upload-purchase-history", 
      "href": "/establish-purchase-history",
      "method": "POST",
      "type": "multipart/form-data",
      "title": "Upload purchase history"
    }
  ]
}
```

## POST /establish-purchase-history
Mock upload endpoint. No real file processing is required.

response will be:
HTTP 202
```json
{
  "message": "Your privacy is important. We are anonymizing your data so no-one can attribute how you spend your money to you personally. Then we pass the data through our machine learning algorithm. Your information will be encrypted on our servers as a precaution. After you get your report, the data is removed.",
  "status": "ACCEPTED",
  "links": [
    {
      "rel": "pii-report-status",
      "href": "/pii-report-status",
      "method": "GET",
      "type": "application/json",
      "title": "Check report status"
    }
  ]
}
```

## GET /pii-report-status
Returns mock completed processing state.

response will be:
HTTP 200
```json
{
  "message": "Your report is ready!",
  "status": "COMPLETE",
  "progressPercent": 100,
  "links": [
    {
      "rel": "pii-report-summary",
      "href": "/pii-summary",
      "method": "GET",
      "type": "application/json",
      "title": "View Personal Inflation summary"
    }
  ]
}
```

## GET /pii-summary
response will be:
HTTP 200
```json
{
  "message": "Your purchasing data is compared with the national average. This is your personal inflation index and report. Please Print your report or save this page as it will be removed from our servers to protect your privacy.",
  "personalInflation": 6.2,
  "nationalCPI": 3.1,
  "links": []
}
```

# Acceptance criteria
- A public AWS API Gateway mock API is created using Terraform.
- The API requires no authentication.
- Terraform outputs the API invoke URL.
- The API exposes the following endpoints under `/api/v1`:
  - `GET /welcome`
  - `POST /establish-purchase-history`
  - `GET /pii-report-status`
  - `GET /pii-summary`
- Every response uses `application/json`.
- Every response contains HATEOAS `links` where a next action is available.
- Link objects include at least `rel`, `href`, and `method`.
- The status endpoint returns mock `COMPLETE` status and a summary link.
- The summary endpoint returns mock PII, national CPI
- Web developers can navigate the full flow by following links without hard-coding endpoint paths other than the initial `/welcome` URL.