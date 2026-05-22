# Skill Catalog

This directory is the Git source of truth for agent skills.

Each file in `skills/catalog/` is a skill manifest. A skill is not available to agents just because it exists in Git. It must pass validation, receive the required reviews, merge to the approved branch, and be deployed into the Cosmos DB skill registry.

## Lifecycle

1. Create or update a skill manifest.
2. Open a pull request.
3. Pass automated validation.
4. Receive business owner review.
5. Receive security review.
6. Merge to the approved branch.
7. Publish to Cosmos DB skill registry.
8. Agents discover it through `/skills/search` or `/skills/groups`.

## Current Examples

- `marketing-social-post-draft.skill.json`: content creation skill for social media agents.
- `marketing-campaign-analysis.skill.json`: analysis skill for marketing analyst agents.

These are intentionally different so the hub can distinguish content creation from analysis even when both belong to Marketing.
