# Story 1 — Ticket Number / Session Token
As a new user landing on the front end, I want a ticket ID minted and returned to my browser as a signed token, 
so that every later request can be authorized without a database lookup.

# Flow
Front end calls a start route on API Gateway.
API Gateway invokes a Lambda that mints a ticket ID (UUID).
Lambda signs the ticket ID into a JWT and returns the token.

# Acceptance Criteria
The JWT contains the ticket ID as a claim.
The token is signed with a key the API Gateway authorizer can verify.
The token has a sensible expiry (~24h, aligned with the DynamoDB TTL).
Every subsequent call carries the token in the Authorization header.