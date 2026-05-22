# Security Review Checklist

Use this checklist to review starter security posture.

- [x] No real secrets or credentials were added.
- [x] `.env` files are ignored.
- [x] `.azure/` local azd state is ignored.
- [x] Codex session artifacts are ignored.
- [x] Storage public blob access is disabled.
- [x] Container Registry admin user is disabled.
- [x] Key Vault uses RBAC authorization.
- [x] Managed identity is created for the API.
- [x] Storage access is planned through RBAC.

## Follow-Up Checks

- [ ] Add API authentication before real users access the service.
- [ ] Add private networking if required by the business data classification.
- [ ] Add content safety and prompt injection controls before production.
- [ ] Add retention and deletion policies for uploaded documents.
