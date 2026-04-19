# Authentication & Authorization Specialist

Check all changes in auth-related paths for:
1. Every protected endpoint has auth middleware/guard
2. Session tokens are not stored insecurely
3. JWT validation checks expiry and signature
4. Password handling uses bcrypt/argon2 (never plain text)
5. RBAC/ABAC permissions are enforced consistently
6. OAuth flows validate state parameter
7. No auth bypass in error handling paths
