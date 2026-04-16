# Invariants & Project Profile

## INV-1: Authentication guards on all protected endpoints
Every endpoint handling user data must have auth middleware/guards applied.

## INV-2: Input validation on all API endpoints
Every endpoint accepting user input must validate and sanitize before processing.

---

## Project Profile

- **Archetype**: api-service
- **Maturity**: active
- **Complexity**: complex

### Archetype Invariants

- [SVC-1]: All endpoints must be documented in OpenAPI/GraphQL schema
- [SVC-2]: All endpoints must have request/response validation
- [SVC-3]: Health check endpoint must exist at /health or /healthz

---

## Review Specialists

### Authentication & Authorization
Trigger paths: tools/review-specialists/auth.md

- [ ] All protected endpoints have auth middleware
- [ ] Session tokens are validated on every request
- [ ] Password hashing uses bcrypt/argon2 (never MD5/SHA1)
- [ ] JWT secrets are not hardcoded
- [ ] Rate limiting on login/register endpoints
- [ ] CSRF protection enabled for state-changing operations
- [ ] Logout invalidates session/token server-side

### API Layer
Trigger paths: tools/review-specialists/api.md

- [ ] All inputs validated before processing
- [ ] Error responses use consistent format
- [ ] Rate limiting configured for public endpoints
- [ ] CORS policy is restrictive (not wildcard)
- [ ] Response types are explicitly defined
- [ ] No sensitive data in URL parameters
- [ ] Pagination on list endpoints
- [ ] API versioning strategy documented

