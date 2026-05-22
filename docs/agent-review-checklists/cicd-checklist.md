# CI/CD Review Checklist

Use this checklist to review deployment automation.

- [x] `.github/workflows/deploy.yml` exists.
- [x] Workflow validates Bicep templates.
- [x] Workflow includes a manual deployment path.
- [x] Workflow uses OIDC-friendly Azure login settings.
- [x] Workflow does not store credentials in source code.
- [x] Deployment is guarded behind `workflow_dispatch`.

## Follow-Up Checks

- [ ] Configure `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` repository secrets.
- [ ] Configure Azure federated identity credentials for GitHub Actions.
- [ ] Confirm repository environment protection rules.
- [ ] Run the workflow against a non-production subscription.
