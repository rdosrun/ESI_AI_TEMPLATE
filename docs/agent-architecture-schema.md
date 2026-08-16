# Agent Architecture Schema and Versioning

The canonical version `1.0` contract is [`schemas/agent-architecture.schema.json`](../schemas/agent-architecture.schema.json). It defines the portable JSON produced by the Flutter Agent Builder so future persistence and runtime services can validate the same document shape.

## Validation boundary

The browser should validate documents to give designers quick feedback. Any future save, test, review, or deployment API must validate the document again because browser validation is not a security boundary. In addition to JSON Schema, the backend must verify that node IDs are unique, every edge and integration reference points to an existing compatible node, condition labels match branches, URLs and credential references meet the organization's allowlists, and configured size limits are respected.

## Migration policy

- Patch releases may clarify documentation but must not change accepted JSON.
- Backward-compatible optional fields may be added within `1.x`; readers must ignore optional fields they do not use.
- Breaking field, type, or semantic changes require a new major schema version such as `2.0` and a separate schema file.
- Importers must reject unknown major versions with a useful message rather than silently dropping data.
- A future migration service must preserve the original document, produce a deterministic upgraded copy, record source and target versions, and be covered by fixture-based tests.
- Deployed architecture versions are immutable. Migration creates a new draft version and never changes an approved or deployed record in place.

TODO: Add the authoritative cross-reference and policy checks to the selected persistence API once its ownership is decided. Add matching client-side errors beside blocks after the Flutter validation service is introduced.
