import base64
import asyncio
import json
import os
from copy import deepcopy
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from threading import Lock
from typing import Any
from uuid import uuid4

from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential
from jsonschema import Draft202012Validator, FormatChecker
from starlette.requests import Request
from starlette.responses import JSONResponse

from agent_runtime import (
    AgentRuntimeError,
    AzureOpenAIAgentRuntime,
    compile_runtime_manifest,
)


API_DIRECTORY = Path(__file__).resolve().parent
PACKAGED_SCHEMA_PATH = API_DIRECTORY / "schemas" / "agent-architecture.schema.json"
REPOSITORY_SCHEMA_PATH = API_DIRECTORY.parent.parent / "schemas" / "agent-architecture.schema.json"
SCHEMA_PATH = (
    REPOSITORY_SCHEMA_PATH if REPOSITORY_SCHEMA_PATH.exists() else PACKAGED_SCHEMA_PATH
)
ARCHITECTURE_SCHEMA = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
SCHEMA_VALIDATOR = Draft202012Validator(
    ARCHITECTURE_SCHEMA,
    format_checker=FormatChecker(),
)

@dataclass(frozen=True)
class AuthenticatedPrincipal:
    user_id: str
    user_details: str
    roles: tuple[str, ...]


def principal_from_request(request: Request) -> AuthenticatedPrincipal | None:
    """Read identity only from the header injected by the linked Static Web App."""
    encoded = request.headers.get("x-ms-client-principal", "")
    if not encoded:
        return None
    try:
        padding = "=" * (-len(encoded) % 4)
        payload = json.loads(base64.b64decode(encoded + padding).decode("utf-8"))
        roles = tuple(str(role) for role in payload.get("userRoles", []))
        user_id = str(payload.get("userId", "")).strip()
        if not user_id or "authenticated" not in roles:
            return None
        return AuthenticatedPrincipal(
            user_id=user_id,
            user_details=str(payload.get("userDetails", "Signed-in Microsoft user")),
            roles=roles,
        )
    except (ValueError, TypeError, UnicodeDecodeError, json.JSONDecodeError):
        return None


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def validate_architecture(architecture: Any, *, deployment_ready: bool = False) -> list[str]:
    errors = [
        f"{'.'.join(str(part) for part in error.absolute_path) or '$'}: {error.message}"
        for error in sorted(SCHEMA_VALIDATOR.iter_errors(architecture), key=str)
    ]
    if errors or not isinstance(architecture, dict):
        return errors

    nodes = architecture["nodes"]
    edges = architecture["edges"]
    node_ids = [node["id"] for node in nodes]
    if len(node_ids) != len(set(node_ids)):
        errors.append("nodes: node IDs must be unique")

    edge_ids = [edge["id"] for edge in edges]
    if len(edge_ids) != len(set(edge_ids)):
        errors.append("edges: edge IDs must be unique")

    known_nodes = set(node_ids)
    for edge in edges:
        if edge["from"] not in known_nodes:
            errors.append(f"edges.{edge['id']}: unknown source node '{edge['from']}'")
        if edge["to"] not in known_nodes:
            errors.append(f"edges.{edge['id']}: unknown destination node '{edge['to']}'")

    if deployment_ready:
        start_count = sum(node["type"] == "start" for node in nodes)
        agent_count = sum(node["type"] == "agent" for node in nodes)
        if start_count != 1:
            errors.append("nodes: a deployable architecture must contain exactly one start node")
        if agent_count < 1:
            errors.append("nodes: a deployable architecture must contain at least one agent node")

    return errors


class ArchitectureRepository:
    """Cosmos-backed repository with an in-memory fallback for local demos."""

    def __init__(self) -> None:
        self._architectures: dict[str, dict[str, Any]] = {}
        self._deployments: dict[str, dict[str, Any]] = {}
        self._lock = Lock()
        self._architecture_container = None
        self._deployment_container = None
        self._configure_cosmos()

    @property
    def mode(self) -> str:
        return "cosmos" if self._architecture_container is not None else "memory"

    def _configure_cosmos(self) -> None:
        endpoint = os.getenv("AZURE_COSMOS_SKILL_REGISTRY_ENDPOINT", "")
        database_name = os.getenv("AZURE_COSMOS_SKILL_REGISTRY_DATABASE", "")
        architecture_container = os.getenv("AZURE_COSMOS_ARCHITECTURES_CONTAINER", "")
        deployment_container = os.getenv("AZURE_COSMOS_DEPLOYMENTS_CONTAINER", "")
        if not all((endpoint, database_name, architecture_container, deployment_container)):
            return

        client = CosmosClient(endpoint, credential=DefaultAzureCredential())
        database = client.get_database_client(database_name)
        self._architecture_container = database.get_container_client(architecture_container)
        self._deployment_container = database.get_container_client(deployment_container)

    def save(
        self,
        architecture: dict[str, Any],
        owner_id: str,
        owner_details: str,
        architecture_id: str | None = None,
    ) -> dict[str, Any]:
        identifier = architecture_id or str(uuid4())
        previous = self.get(identifier, owner_id) if architecture_id else None
        version = int(previous["version"]) + 1 if previous else 1
        record = {
            "id": identifier,
            "ownerId": owner_id,
            "ownerDetails": owner_details,
            "version": version,
            "status": "draft",
            "createdAt": previous["createdAt"] if previous else utc_now(),
            "updatedAt": utc_now(),
            "architecture": deepcopy(architecture),
        }
        if self._architecture_container is not None:
            self._architecture_container.upsert_item(record)
        else:
            with self._lock:
                self._architectures[identifier] = record
        return deepcopy(record)

    def get(self, architecture_id: str, owner_id: str) -> dict[str, Any] | None:
        if self._architecture_container is not None:
            try:
                record = self._architecture_container.read_item(
                    item=architecture_id,
                    partition_key=owner_id,
                )
            except Exception as error:
                if getattr(error, "status_code", None) == 404:
                    return None
                raise
            return dict(record)
        with self._lock:
            record = self._architectures.get(architecture_id)
            return deepcopy(record) if record else None

    def request_deployment(
        self,
        architecture_record: dict[str, Any],
        owner_id: str,
        owner_details: str,
    ) -> dict[str, Any]:
        deployment_id = str(uuid4())
        manifest = compile_runtime_manifest(architecture_record["architecture"])
        record = {
            "id": deployment_id,
            "architectureId": architecture_record["id"],
            "architectureVersion": architecture_record["version"],
            "ownerId": owner_id,
            "ownerDetails": owner_details,
            "status": "active",
            "endpoint": f"/api/deployments/{deployment_id}/invoke",
            "runtimeManifest": manifest,
            "createdAt": utc_now(),
            "updatedAt": utc_now(),
            "message": (
                "The architecture is published and ready to invoke with the configured Azure AI model."
            ),
        }
        if self._deployment_container is not None:
            self._deployment_container.create_item(record)
        else:
            with self._lock:
                self._deployments[deployment_id] = record
        return deepcopy(record)

    def get_deployment(self, deployment_id: str, owner_id: str) -> dict[str, Any] | None:
        if self._deployment_container is not None:
            records = list(
                self._deployment_container.query_items(
                    query=(
                        "SELECT * FROM deployments d "
                        "WHERE d.id = @id AND d.ownerId = @ownerId"
                    ),
                    parameters=[
                        {"name": "@id", "value": deployment_id},
                        {"name": "@ownerId", "value": owner_id},
                    ],
                    enable_cross_partition_query=True,
                )
            )
            return dict(records[0]) if records else None
        with self._lock:
            record = self._deployments.get(deployment_id)
            if record is None or record["ownerId"] != owner_id:
                return None
            return deepcopy(record)

    def list_deployments(
        self, owner_id: str, search: str = ""
    ) -> list[dict[str, Any]]:
        if self._deployment_container is not None:
            records = list(
                self._deployment_container.query_items(
                    query=(
                        "SELECT * FROM deployments d "
                        "WHERE d.ownerId = @ownerId AND d.status = 'active'"
                    ),
                    parameters=[{"name": "@ownerId", "value": owner_id}],
                    enable_cross_partition_query=True,
                )
            )
        else:
            with self._lock:
                records = [
                    deepcopy(record)
                    for record in self._deployments.values()
                    if record["ownerId"] == owner_id and record["status"] == "active"
                ]
        term = search.casefold().strip()
        if term:
            records = [
                record
                for record in records
                if term
                in str(record.get("runtimeManifest", {}).get("name", "")).casefold()
            ]
        records.sort(key=lambda record: str(record.get("createdAt", "")), reverse=True)
        return records


def register_architecture_routes(
    mcp: Any,
    repository: ArchitectureRepository,
    runtime: AzureOpenAIAgentRuntime | None = None,
) -> None:
    runtime = runtime or AzureOpenAIAgentRuntime()
    def response_error(message: str, status_code: int, details: list[str] | None = None) -> JSONResponse:
        body: dict[str, Any] = {"error": message}
        if details:
            body["details"] = details
        return JSONResponse(body, status_code=status_code)

    def require_principal(request: Request) -> tuple[AuthenticatedPrincipal | None, JSONResponse | None]:
        principal = principal_from_request(request)
        if principal is None:
            return None, response_error("Microsoft sign-in is required.", 401)
        return principal, None

    @mcp.custom_route("/api/architectures", methods=["POST"])
    async def create_architecture(request: Request) -> JSONResponse:
        principal, unauthorized = require_principal(request)
        if unauthorized is not None:
            return unauthorized
        try:
            architecture = await request.json()
        except (json.JSONDecodeError, UnicodeDecodeError):
            return response_error("Request body must be valid JSON.", 400)
        errors = validate_architecture(architecture)
        if errors:
            return response_error("Architecture validation failed.", 422, errors)
        record = repository.save(
            architecture,
            principal.user_id,
            principal.user_details,
        )
        return JSONResponse(record, status_code=201)

    @mcp.custom_route("/api/architectures/{architecture_id}", methods=["GET"])
    async def get_architecture(request: Request) -> JSONResponse:
        principal, unauthorized = require_principal(request)
        if unauthorized is not None:
            return unauthorized
        record = repository.get(request.path_params["architecture_id"], principal.user_id)
        if record is None:
            return response_error("Architecture not found.", 404)
        return JSONResponse(record)

    @mcp.custom_route("/api/architectures/{architecture_id}", methods=["PUT"])
    async def update_architecture(request: Request) -> JSONResponse:
        principal, unauthorized = require_principal(request)
        if unauthorized is not None:
            return unauthorized
        architecture_id = request.path_params["architecture_id"]
        if repository.get(architecture_id, principal.user_id) is None:
            return response_error("Architecture not found.", 404)
        try:
            architecture = await request.json()
        except (json.JSONDecodeError, UnicodeDecodeError):
            return response_error("Request body must be valid JSON.", 400)
        errors = validate_architecture(architecture)
        if errors:
            return response_error("Architecture validation failed.", 422, errors)
        return JSONResponse(
            repository.save(
                architecture,
                principal.user_id,
                principal.user_details,
                architecture_id,
            )
        )

    @mcp.custom_route("/api/architectures/{architecture_id}/deploy", methods=["POST"])
    async def deploy_architecture(request: Request) -> JSONResponse:
        principal, unauthorized = require_principal(request)
        if unauthorized is not None:
            return unauthorized
        record = repository.get(request.path_params["architecture_id"], principal.user_id)
        if record is None:
            return response_error("Architecture not found.", 404)
        errors = validate_architecture(record["architecture"], deployment_ready=True)
        if errors:
            return response_error("Architecture is not deployment-ready.", 422, errors)
        if not runtime.configured:
            return response_error("The Azure AI model runtime is not configured.", 503)
        try:
            runtime.validate_manifest(compile_runtime_manifest(record["architecture"]))
        except AgentRuntimeError as error:
            return response_error(str(error), 422)
        deployment = repository.request_deployment(
            record,
            principal.user_id,
            principal.user_details,
        )
        return JSONResponse(deployment, status_code=201)

    @mcp.custom_route("/api/deployments/{deployment_id}", methods=["GET"])
    async def get_deployment(request: Request) -> JSONResponse:
        principal, unauthorized = require_principal(request)
        if unauthorized is not None:
            return unauthorized
        deployment = repository.get_deployment(
            request.path_params["deployment_id"], principal.user_id
        )
        if deployment is None:
            return response_error("Deployment not found.", 404)
        return JSONResponse(deployment)

    @mcp.custom_route("/api/deployments", methods=["GET"])
    async def list_deployments(request: Request) -> JSONResponse:
        principal, unauthorized = require_principal(request)
        if unauthorized is not None:
            return unauthorized
        deployments = repository.list_deployments(
            principal.user_id,
            request.query_params.get("search", ""),
        )
        return JSONResponse(
            {
                "items": [
                    {
                        "id": deployment["id"],
                        "architectureId": deployment["architectureId"],
                        "architectureVersion": deployment["architectureVersion"],
                        "name": deployment.get("runtimeManifest", {}).get(
                            "name", "Deployed agent"
                        ),
                        "runtimeVersion": deployment.get("runtimeManifest", {}).get(
                            "runtimeVersion", "1.0"
                        ),
                        "status": deployment["status"],
                        "endpoint": deployment["endpoint"],
                        "createdAt": deployment["createdAt"],
                    }
                    for deployment in deployments
                ]
            }
        )

    @mcp.custom_route("/api/deployments/{deployment_id}/invoke", methods=["POST"])
    async def invoke_deployment(request: Request) -> JSONResponse:
        principal, unauthorized = require_principal(request)
        if unauthorized is not None:
            return unauthorized
        deployment = repository.get_deployment(
            request.path_params["deployment_id"], principal.user_id
        )
        if deployment is None:
            return response_error("Deployment not found.", 404)
        try:
            body = await request.json()
            user_input = str(body.get("input", "")).strip()
        except (AttributeError, json.JSONDecodeError, UnicodeDecodeError):
            return response_error("Request body must be a JSON object.", 400)
        if not user_input:
            return response_error("input is required.", 400)
        try:
            result = await asyncio.to_thread(
                runtime.invoke,
                deployment["runtimeManifest"],
                user_input,
            )
        except AgentRuntimeError as error:
            return response_error(str(error), 502)
        return JSONResponse(
            {
                "deploymentId": deployment["id"],
                "architectureId": deployment["architectureId"],
                **result,
            }
        )
