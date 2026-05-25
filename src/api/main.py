import os
from datetime import datetime, timezone
from typing import Annotated

from fastapi import FastAPI, File, UploadFile
from pydantic import BaseModel, Field


class AskRequest(BaseModel):
    question: str = Field(..., min_length=1, description="Business question to answer.")
    department: str | None = Field(default=None, description="Optional team or workflow context.")


class AskResponse(BaseModel):
    answer: str
    status: str
    next_steps: list[str]
    citations: list[str]


class SkillSearchRequest(BaseModel):
    query: str = Field(..., min_length=1, description="Natural language skill lookup query.")
    department: str | None = Field(default=None, description="Optional department filter.")
    task_type: str | None = Field(default=None, description="Optional task or workflow filter.")
    limit: int = Field(default=5, ge=1, le=20, description="Maximum matching skills to return.")


class SkillGroupRequest(BaseModel):
    department: str | None = Field(default=None, description="Department such as marketing or operations.")
    task_type: str | None = Field(default=None, description="Task type such as content creation or analysis.")


app = FastAPI(
    title="ESI Azure AI Proof-of-Concept API",
    version="0.1.0",
    description="Starter API for AI workflow, document upload, and KPI demonstration.",
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@app.get("/health")
def health() -> dict[str, str]:
    return {
        "status": "ok",
        "service": "esi-ai-api",
        "checked_at": utc_now(),
    }


@app.get("/metrics")
def metrics() -> dict[str, object]:
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


@app.post("/upload")
async def upload(file: Annotated[UploadFile, File(...)]) -> dict[str, object]:
    # TODO: Stream the file to Azure Blob Storage using managed identity.
    return {
        "status": "accepted_placeholder",
        "filename": file.filename,
        "content_type": file.content_type,
        "target_storage_account": os.getenv("AZURE_STORAGE_ACCOUNT_NAME", ""),
        "target_container": os.getenv("AZURE_STORAGE_DOCUMENT_CONTAINER", ""),
        "next_steps": [
            "Persist file to Blob Storage.",
            "Trigger document extraction and chunking.",
            "Index approved chunks in Azure AI Search.",
        ],
    }


@app.post("/ask", response_model=AskResponse)
async def ask(request: AskRequest) -> AskResponse:
    # TODO: Retrieve relevant chunks from Azure AI Search and call the approved model deployment.
    model_endpoint = os.getenv("AZURE_AI_FOUNDRY_ENDPOINT") or os.getenv("AZURE_OPENAI_ENDPOINT")
    model_deployment = os.getenv("AZURE_AI_FOUNDRY_DEPLOYMENT_NAME") or os.getenv(
        "AZURE_OPENAI_DEPLOYMENT_NAME"
    )
    openai_ready = bool(
        model_endpoint and model_deployment
    )
    readiness_note = (
        "Azure AI Foundry model configuration is present."
        if openai_ready
        else "Azure AI Foundry model configuration is not present yet."
    )

    return AskResponse(
        status="placeholder",
        answer=(
            "This starter API received the question but does not call an LLM yet. "
            f"{readiness_note} The next implementation step is retrieval plus grounded generation."
        ),
        citations=[],
        next_steps=[
            "Define the approved document corpus.",
            "Create the Azure AI Search index schema.",
            "Add retrieval, prompt assembly, model call, and citation validation.",
        ],
    )


@app.post("/skills/search")
async def search_skills(request: SkillSearchRequest) -> dict[str, object]:
    # TODO: Embed the query, run Cosmos DB vector search, and return ranked skill records.
    return {
        "status": "placeholder",
        "query": request.query,
        "filters": {
            "department": request.department,
            "task_type": request.task_type,
            "limit": request.limit,
        },
        "skill_registry": {
            "endpoint_configured": bool(os.getenv("AZURE_COSMOS_SKILL_REGISTRY_ENDPOINT")),
            "database": os.getenv("AZURE_COSMOS_SKILL_REGISTRY_DATABASE", ""),
            "container": os.getenv("AZURE_COSMOS_SKILL_REGISTRY_CONTAINER", ""),
        },
        "matches": [
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
        ],
        "next_steps": [
            "Create embeddings for each skill description.",
            "Store skills and metadata in Cosmos DB.",
            "Use vector similarity plus department/task filters for agent routing.",
        ],
    }


@app.post("/skills/groups")
async def list_skill_groups(request: SkillGroupRequest) -> dict[str, object]:
    # TODO: Read group definitions from the skill-groups Cosmos DB container.
    return {
        "status": "placeholder",
        "filters": {
            "department": request.department,
            "task_type": request.task_type,
        },
        "groups": [
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
        ],
        "next_steps": [
            "Persist group definitions in Cosmos DB.",
            "Expose group selection to agent orchestration.",
            "Add governance rules for which agents can use each skill group.",
        ],
    }
