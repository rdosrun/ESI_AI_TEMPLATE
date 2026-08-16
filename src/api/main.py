import os
from datetime import datetime, timezone

from fastmcp import FastMCP
from starlette.middleware.cors import CORSMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

from architecture_api import ArchitectureRepository, register_architecture_routes


mcp = FastMCP(
    name="ESI Azure AI Solutions Architect Starter",
    instructions=(
        "Governed Azure AI tools for document intake, grounded question answering, "
        "KPI reporting, and approved agent-skill discovery. Placeholder results clearly "
        "identify integrations that still need to be implemented."
    ),
)

architecture_repository = ArchitectureRepository()
register_architecture_routes(mcp, architecture_repository)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@mcp.custom_route("/health", methods=["GET"])
@mcp.custom_route("/api/health", methods=["GET"])
async def health(_request: Request) -> JSONResponse:
    """Unauthenticated operational health probe for Azure Container Apps."""
    return JSONResponse(
        {
            "status": "ok",
            "service": "esi-ai-mcp",
            "transport": "streamable-http",
            "mcp_endpoint": "/api/mcp",
            "checked_at": utc_now(),
            "architecture_store": architecture_repository.mode,
        }
    )


@mcp.tool
def get_metrics() -> dict[str, object]:
    """Return starter business and operational KPI measurements."""
    return {
        "generated_at": utc_now(),
        "kpis": {
            "answer_success_rate": {
                "value": 0,
                "unit": "percent",
                "note": "Placeholder until answer evaluation is implemented.",
            },
            "documents_uploaded": {
                "value": 0,
                "unit": "count",
                "note": "Placeholder until Blob Storage upload is wired.",
            },
            "average_response_time_seconds": {
                "value": 0,
                "unit": "seconds",
                "note": "Placeholder until telemetry aggregation is wired.",
            },
            "human_escalation_rate": {
                "value": 0,
                "unit": "percent",
                "note": "Placeholder until feedback capture is implemented.",
            },
        },
    }


@mcp.tool
def upload_document(
    filename: str,
    content_type: str = "application/octet-stream",
    source_uri: str | None = None,
) -> dict[str, object]:
    """Register an approved document for future Blob Storage ingestion and indexing.

    This starter does not accept document bytes yet. Provide a source URI that a future
    governed ingestion worker can read, or use the filename to review the tool contract.
    """
    # TODO: Read from an approved source URI and stream the file to Blob Storage using managed identity.
    return {
        "status": "accepted_placeholder",
        "filename": filename,
        "content_type": content_type,
        "source_uri": source_uri,
        "target_storage_account": os.getenv("AZURE_STORAGE_ACCOUNT_NAME", ""),
        "target_container": os.getenv("AZURE_STORAGE_DOCUMENT_CONTAINER", ""),
        "next_steps": [
            "Persist the approved document to Blob Storage.",
            "Trigger document extraction and chunking.",
            "Index approved chunks in Azure AI Search.",
        ],
    }


@mcp.tool
def ask_question(question: str, department: str | None = None) -> dict[str, object]:
    """Answer a business question using approved enterprise knowledge sources."""
    if not question.strip():
        raise ValueError("question must not be empty")

    # TODO: Retrieve relevant chunks from Azure AI Search and call the approved model deployment.
    model_endpoint = os.getenv("AZURE_AI_FOUNDRY_ENDPOINT") or os.getenv("AZURE_OPENAI_ENDPOINT")
    model_deployment = os.getenv("AZURE_AI_FOUNDRY_DEPLOYMENT_NAME") or os.getenv(
        "AZURE_OPENAI_DEPLOYMENT_NAME"
    )
    readiness_note = (
        "Azure AI Foundry model configuration is present."
        if model_endpoint and model_deployment
        else "Azure AI Foundry model configuration is not present yet."
    )

    return {
        "status": "placeholder",
        "question": question,
        "department": department,
        "answer": (
            "This MCP server received the question but does not call an LLM yet. "
            f"{readiness_note} The next implementation step is retrieval plus grounded generation."
        ),
        "citations": [],
        "next_steps": [
            "Define the approved document corpus.",
            "Create the Azure AI Search index schema.",
            "Add retrieval, prompt assembly, model call, and citation validation.",
        ],
    }


@mcp.tool
def search_skills(
    query: str,
    department: str | None = None,
    task_type: str | None = None,
    limit: int = 5,
) -> dict[str, object]:
    """Find approved agent skills using natural language and optional business filters."""
    if not query.strip():
        raise ValueError("query must not be empty")
    if not 1 <= limit <= 20:
        raise ValueError("limit must be between 1 and 20")

    # TODO: Embed the query, run Cosmos DB vector search, and return ranked approved skills.
    matches = [
        {
            "skill_id": "marketing-social-post-draft",
            "name": "Create social media post",
            "department": "marketing",
            "task_type": "content_creation",
            "description": "Drafts channel-specific social posts from approved campaign context.",
        },
        {
            "skill_id": "marketing-campaign-analysis",
            "name": "Analyze marketing campaign performance",
            "department": "marketing",
            "task_type": "analysis",
            "description": "Summarizes campaign KPIs and highlights performance drivers.",
        },
    ]
    filtered_matches = [
        skill
        for skill in matches
        if (department is None or skill["department"] == department)
        and (task_type is None or skill["task_type"] == task_type)
    ][:limit]

    return {
        "status": "placeholder",
        "query": query,
        "filters": {"department": department, "task_type": task_type, "limit": limit},
        "skill_registry": {
            "endpoint_configured": bool(os.getenv("AZURE_COSMOS_SKILL_REGISTRY_ENDPOINT")),
            "database": os.getenv("AZURE_COSMOS_SKILL_REGISTRY_DATABASE", ""),
            "container": os.getenv("AZURE_COSMOS_SKILL_REGISTRY_CONTAINER", ""),
        },
        "matches": filtered_matches,
        "next_steps": [
            "Create embeddings for each skill description.",
            "Store approved skills and metadata in Cosmos DB.",
            "Use vector similarity plus governance filters for agent routing.",
        ],
    }


@mcp.tool
def list_skill_groups(
    department: str | None = None,
    task_type: str | None = None,
) -> dict[str, object]:
    """List approved skill bundles by department and task type for agent routing."""
    # TODO: Read approved group definitions from the skill-groups Cosmos DB container.
    groups = [
        {
            "group_id": "marketing-content-creation",
            "department": "marketing",
            "task_type": "content_creation",
            "agent_type": "social_media_post_creator",
            "skills": [
                "marketing-social-post-draft",
                "marketing-brand-voice-check",
                "marketing-hashtag-suggest",
            ],
        },
        {
            "group_id": "marketing-analysis",
            "department": "marketing",
            "task_type": "analysis",
            "agent_type": "marketing_analyst",
            "skills": [
                "marketing-campaign-analysis",
                "marketing-audience-segment-summary",
                "marketing-kpi-variance-explain",
            ],
        },
    ]
    filtered_groups = [
        group
        for group in groups
        if (department is None or group["department"] == department)
        and (task_type is None or group["task_type"] == task_type)
    ]

    return {
        "status": "placeholder",
        "filters": {"department": department, "task_type": task_type},
        "groups": filtered_groups,
        "next_steps": [
            "Persist approved group definitions in Cosmos DB.",
            "Expose group selection to agent orchestration.",
            "Enforce which agents can use each skill group.",
        ],
    }


# Stateless transport allows Container Apps to route requests across replicas without session affinity.
allowed_origins = [
    origin.strip()
    for origin in os.getenv("CORS_ALLOWED_ORIGINS", "http://localhost:8080").split(",")
    if origin.strip()
]
app = CORSMiddleware(
    app=mcp.http_app(path="/api/mcp", stateless_http=True),
    allow_origins=allowed_origins,
    allow_methods=["GET", "POST", "PUT", "OPTIONS"],
    allow_headers=["Content-Type"],
)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
