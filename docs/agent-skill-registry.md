# Agent Skill Registry

The starter kit includes a skill registry concept so an agent can look up the right skill for a natural language request. This keeps agent behavior easier to govern than hardcoding every route inside the agent.

## Business Purpose

Different departments need different AI behaviors. Even inside one department, a content creation agent should not behave the same way as an analysis agent.

Example:

- A **marketing social media post creation agent** needs brand voice, campaign context, channel rules, and approval workflow skills.
- A **marketing analysis agent** needs KPI interpretation, segmentation, trend explanation, and source citation skills.

Both are marketing agents, but they should use different skill groups.

## Azure Service

The starter uses **Azure Cosmos DB for NoSQL with vector search enabled** as the skill registry database.

Why Cosmos DB:

- Stores structured skill metadata such as department, task type, owner, risk level, and tool name.
- Stores vector embeddings for natural language skill lookup.
- Supports filtered lookup by department or task.
- Gives agents a database-backed registry instead of relying only on prompt text.
- Can be accessed with managed identity instead of hardcoded keys.

Azure AI Search still handles document retrieval for RAG. Cosmos DB handles agent skill and tool lookup.

## Data Model

### Skill Record

```json
{
  "id": "marketing-social-post-draft",
  "skillId": "marketing-social-post-draft",
  "name": "Create social media post",
  "department": "marketing",
  "taskType": "content_creation",
  "agentType": "social_media_post_creator",
  "description": "Drafts channel-specific social posts from approved campaign context.",
  "inputs": ["campaign_brief", "channel", "audience", "tone"],
  "outputs": ["draft_post", "approval_notes"],
  "riskLevel": "medium",
  "requiresHumanApproval": true,
  "embedding": [0.0123, -0.0456]
}
```

### Skill Group Record

```json
{
  "id": "marketing-content-creation",
  "groupId": "marketing-content-creation",
  "department": "marketing",
  "taskType": "content_creation",
  "agentType": "social_media_post_creator",
  "description": "Skills for drafting and checking marketing social posts.",
  "skillIds": [
    "marketing-social-post-draft",
    "marketing-brand-voice-check",
    "marketing-hashtag-suggest"
  ],
  "allowedChannels": ["teams", "sharepoint", "office-addin", "hermes"],
  "requiresHumanApproval": true
}
```

## Lookup Flow

1. A user asks an agent to perform a task.
2. The agent calls `POST /skills/search` with the natural language request.
3. The API embeds the request.
4. Cosmos DB vector search finds similar skills.
5. The API applies filters such as department, task type, risk level, and allowed channel.
6. The agent receives ranked skills or a recommended skill group.
7. The agent executes only approved skills for that group.

## API Placeholders

The starter API includes:

- `POST /skills/search` for natural language skill lookup.
- `POST /skills/groups` for department/task group discovery.

These endpoints currently return placeholder data so the contract can be reviewed before implementing persistence.

## Example Skill Grouping

| Department | Agent Type | Task Type | Example Skills |
| --- | --- | --- | --- |
| Marketing | Social media post creator | Content creation | Draft post, brand voice check, hashtag suggestion, approval summary |
| Marketing | Marketing analyst | Analysis | Campaign KPI summary, segment comparison, trend explanation, budget variance explanation |
| HR | Policy assistant | SOP support | Find policy, summarize changes, explain eligibility, escalate to HR owner |
| Operations | Process improvement analyst | Analysis | Identify bottleneck, summarize ticket themes, suggest SOP update |
| Sales | Proposal assistant | Content creation | Draft response, align to customer pain, retrieve approved case study |

## Governance Rules

- Skills should have owners.
- Skill groups should be approved by department leaders.
- High-impact skills should require human approval.
- Agents should only use skills allowed for their channel and role.
- Skill lookup should be logged for audit and KPI tracking.
- Deprecated skills should remain traceable but unavailable for new executions.

## Implementation TODOs

- Add Cosmos SDK dependency after choosing the Python package version.
- Add embedding generation for skill descriptions.
- Seed starter skill and skill-group records.
- Implement vector search in `/skills/search`.
- Add role/channel filters before returning executable skills.
- Add audit telemetry for skill selection and execution.
