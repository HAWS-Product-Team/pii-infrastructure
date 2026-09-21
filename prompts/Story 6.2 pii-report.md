# Add endpoint to serve the PII report.

As an American, I want to read a report about how inflation impacts me
so that I have the insight to make good decisions on voting, purchasing,
and lifestyle adjustments.

As a Backend Engineer
I want to provision an AWS API Gateway infrastructure using Terraform that serves as the entry point for a HATEOAS-compliant application,
So that I can simulate the user journey (Welcome → Submit Data → Check Status) with static mock responses while
establishing the foundational infrastructure for future dynamic backend integration.

# Acceptance Criteria

1. Terraform Structure
   •   The Terraform code must be organized into two distinct modules:
    *   Root Module: Orchestrates the deployment.
    *   api-gateway Module: Handles the creation of the API Gateway, Stages, Deployments, and Resource definitions.
    *   api-mocks Module: Handles the integration of static mock responses (using aws_api_gateway_integration_response
        or aws_lambda_function if mocking via Lambda is preferred, but per specs, static JSON responses are required).

2. API Gateway Configuration
   •   The API Gateway must be configured to support REST API standards.
   •   The API must be deployed to a stage (e.g., dev or prod).

3. Endpoint Implementation & Mock Responses
   The following endpoints must be implemented with the exact specifications below:

Endpoint 4: pii-report (Authenticated)
•   Path: /pii-report
•   Method: GET
•   Auth: Required (Bearer Token)
•   Headers: Authorization: Bearer <token>
•   Mock Response:

    *   Status: 200 OK
    *   Body:
        ```json
        {
          "message": "Your personal inflation is 14.",
          "links": [
            {
              "rel": "self",
              "href": "/pii-report"
            }
          ]
        }
        ```

4. HATEOAS Compliance
   •   All responses must include a links array adhering to HATEOAS principles.
   •   The rel and href fields must match the specifications exactly.

5. Security & Access Control
   •   The /pii-report endpoint must enforce Bearer Token authentication.

Technical Notes for Implementation
─────────────────────────────────────────────
•   Mocking Strategy: Since this is a mock implementation, consider using aws_api_gateway_integration with
passthroughBehavior and integrationResponses that return static JSON payloads.
The actual validation of this token in the /pii-report endpoint can be simulated using an API Gateway
Authorizer (e.g., a simple Lambda Authorizer that accepts any valid-looking JWT or a custom header check) for demonstration purposes.
•   Follow existing Module Separation: Ensure the api-mocks module is called within the api-gateway module to maintain the requested structure.

Definition of Done
───────────────────────
•   Terraform plan applies successfully without errors.
•   Endpoint is accessible via the deployed API Gateway URL.
•   Mock responses match the specified JSON structure and HTTP status codes.
•   The api-gateway and api-mocks module structure is clearly defined in the codebase.