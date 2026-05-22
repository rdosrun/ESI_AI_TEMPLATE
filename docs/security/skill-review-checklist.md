# Skill Security Review Checklist

Use this checklist before approving a skill manifest for deployment into the skill registry.

## Ownership

- [ ] Business owner is named.
- [ ] Technical owner is named.
- [ ] Department is correct.
- [ ] Task type is correct.
- [ ] Agent type is correct.

## Data Access

- [ ] Allowed data sources are explicit.
- [ ] No sensitive source is included without approval.
- [ ] The skill does not request direct credentials.
- [ ] The skill can run through managed identity or approved service access.

## Risk

- [ ] Risk level is set to `low`, `medium`, or `high`.
- [ ] Human approval is required for high-impact actions.
- [ ] The skill cannot publish, delete, spend money, or notify customers without approval.
- [ ] Prompt injection and unsafe instruction risks are considered.

## Audit

- [ ] Skill version is set.
- [ ] Review metadata is complete before status becomes `approved`.
- [ ] Expected telemetry events are defined.
- [ ] Deprecated or revoked behavior is clear.

## Approval

- [ ] Business reviewer approves.
- [ ] Security reviewer approves.
- [ ] Governance owner approves promotion to the registry.
