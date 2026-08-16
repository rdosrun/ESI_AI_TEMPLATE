import base64
import json

import api_executor
from api_executor import ApiExecutionError, OutboundApiExecutor

from architecture_api import (
    ArchitectureRepository,
    principal_from_request,
    validate_architecture,
)
from agent_runtime import compile_runtime_manifest, extract_response_text
from starlette.requests import Request


def sample_architecture() -> dict:
    return {
        "schemaVersion": "1.0",
        "name": "Customer support",
        "updatedAt": "2026-08-16T12:00:00+00:00",
        "nodes": [
            {
                "id": "start",
                "type": "start",
                "position": {"x": 0, "y": 0},
                "title": "Start",
                "description": "",
                "config": {},
            },
            {
                "id": "agent",
                "type": "agent",
                "position": {"x": 200, "y": 0},
                "title": "Agent",
                "description": "Triage the request",
                "config": {"instructions": "Use approved sources."},
            },
        ],
        "edges": [
            {"id": "edge", "from": "start", "to": "agent", "label": ""}
        ],
    }


def test_valid_architecture_is_deployment_ready(monkeypatch) -> None:
    monkeypatch.delenv("AZURE_COSMOS_SKILL_REGISTRY_ENDPOINT", raising=False)
    assert validate_architecture(sample_architecture(), deployment_ready=True) == []


def test_unknown_edge_reference_is_rejected() -> None:
    architecture = sample_architecture()
    architecture["edges"][0]["to"] = "missing"
    errors = validate_architecture(architecture)
    assert any("unknown destination node" in error for error in errors)


def test_deployment_requires_one_start_and_an_agent() -> None:
    architecture = sample_architecture()
    architecture["nodes"] = architecture["nodes"][:1]
    errors = validate_architecture(architecture, deployment_ready=True)
    assert any("at least one agent" in error for error in errors)


def test_memory_repository_versions_and_records_deployment(monkeypatch) -> None:
    monkeypatch.delenv("AZURE_COSMOS_SKILL_REGISTRY_ENDPOINT", raising=False)
    repository = ArchitectureRepository()
    first = repository.save(sample_architecture(), "user-1", "user@example.com")
    second = repository.save(
        sample_architecture(),
        "user-1",
        "user@example.com",
        first["id"],
    )
    deployment = repository.request_deployment(
        second,
        "user-1",
        "user@example.com",
    )

    assert first["version"] == 1
    assert second["version"] == 2
    assert deployment["architectureId"] == first["id"]
    assert deployment["architectureVersion"] == 2
    assert deployment["status"] == "active"
    assert deployment["endpoint"].endswith(f"/{deployment['id']}/invoke")
    assert "Use approved sources." in deployment["runtimeManifest"]["instructions"]


def test_runtime_manifest_compiles_agent_instructions() -> None:
    manifest = compile_runtime_manifest(sample_architecture())

    assert manifest["runtimeVersion"] == "1.2"
    assert manifest["agentNodeIds"] == ["agent"]
    assert "Customer support" in manifest["instructions"]


def test_deployments_are_owner_scoped_and_searchable(monkeypatch) -> None:
    monkeypatch.delenv("AZURE_COSMOS_SKILL_REGISTRY_ENDPOINT", raising=False)
    repository = ArchitectureRepository()
    first = repository.save(sample_architecture(), "user-1", "one@example.com")
    repository.request_deployment(first, "user-1", "one@example.com")
    other = sample_architecture()
    other["name"] = "Finance helper"
    second = repository.save(other, "user-2", "two@example.com")
    repository.request_deployment(second, "user-2", "two@example.com")

    assert len(repository.list_deployments("user-1")) == 1
    assert repository.list_deployments("user-1", "customer")[0][
        "runtimeManifest"
    ]["name"] == "Customer support"
    assert repository.list_deployments("user-1", "finance") == []


def test_responses_api_visible_text_shapes_are_supported() -> None:
    assert extract_response_text({"output_text": "Direct result"}) == "Direct result"
    assert (
        extract_response_text(
            {
                "output": [
                    {
                        "content": [
                            {"type": "output_text", "text": "Nested result"}
                        ]
                    }
                ]
            }
        )
        == "Nested result"
    )
    assert (
        extract_response_text(
            {"output": [{"content": [{"type": "refusal", "refusal": "No"}]}]}
        )
        == "No"
    )


def test_runtime_manifest_compiles_reachable_api_steps() -> None:
    architecture = sample_architecture()
    architecture["nodes"].append(
        {
            "id": "api",
            "type": "api",
            "position": {"x": 400, "y": 0},
            "title": "Lookup order",
            "description": "Fetch order details",
            "config": {
                "endpoint": "https://api.example.com/orders",
                "protocol": "POST",
                "requestBodyTemplate": '{"query":"{{input}}"}',
            },
        }
    )
    architecture["edges"].append(
        {"id": "api-edge", "from": "agent", "to": "api", "label": ""}
    )

    manifest = compile_runtime_manifest(architecture)

    assert manifest["apiSteps"] == [
        {
            "id": "api",
            "title": "Lookup order",
            "endpoint": "https://api.example.com/orders",
            "method": "POST",
            "requestBodyTemplate": '{"query":"{{input}}"}',
            "credentialReference": "",
            "credentialHeader": "Authorization",
            "credentialScheme": "Bearer",
        }
    ]


def test_agent_incoming_and_referenced_api_is_an_executable_prerequisite() -> None:
    architecture = sample_architecture()
    architecture["nodes"][1]["config"]["integrationRefs"] = ["api"]
    architecture["nodes"].append(
        {
            "id": "api",
            "type": "api",
            "position": {"x": 85, "y": 233},
            "title": "API call",
            "description": "Call an HTTP service",
            "config": {
                "endpoint": "https://jsonplaceholder.typicode.com/todos/1"
            },
        }
    )
    architecture["edges"].append(
        {"id": "api-agent", "from": "api", "to": "agent", "label": ""}
    )

    manifest = compile_runtime_manifest(architecture)

    assert len(manifest["apiSteps"]) == 1
    assert manifest["apiSteps"][0]["id"] == "api"
    assert manifest["apiSteps"][0]["method"] == "GET"


def test_api_executor_calls_allowlisted_public_https_host(monkeypatch) -> None:
    monkeypatch.setenv("AGENT_API_ALLOWED_HOSTS", "api.example.com")
    monkeypatch.setattr(
        api_executor.socket,
        "getaddrinfo",
        lambda *_args: [(None, None, None, None, ("93.184.216.34", 443))],
    )
    captured = {}

    class FakeResponse:
        status = 200
        headers = {"Content-Type": "application/json"}

        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return None

        def read(self, _size):
            return b'{"ok":true}'

    def fake_urlopen(request, timeout):
        captured["request"] = request
        captured["timeout"] = timeout
        return FakeResponse()

    monkeypatch.setattr(api_executor, "_open_url", fake_urlopen)
    executor = OutboundApiExecutor()
    result = executor.execute(
        {
            "id": "api",
            "title": "Lookup",
            "endpoint": "https://api.example.com/run",
            "method": "POST",
            "requestBodyTemplate": '{"prompt":"{{input}}"}',
        },
        "hello",
    )

    assert result.status_code == 200
    assert result.body == '{"ok":true}'
    assert captured["request"].data == b'{"prompt":"hello"}'
    assert captured["timeout"] == 20


def test_api_executor_rejects_unlisted_hosts(monkeypatch) -> None:
    monkeypatch.setenv("AGENT_API_ALLOWED_HOSTS", "approved.example.com")
    executor = OutboundApiExecutor()

    try:
        executor.validate({"endpoint": "https://other.example.com", "method": "GET"})
    except ApiExecutionError as error:
        assert "not in AGENT_API_ALLOWED_HOSTS" in str(error)
    else:
        raise AssertionError("Expected an unlisted host to be rejected")


def test_platform_principal_is_decoded() -> None:
    payload = base64.b64encode(
        json.dumps(
            {
                "userId": "entra-user-1",
                "userDetails": "user@example.com",
                "userRoles": ["anonymous", "authenticated"],
            }
        ).encode()
    ).decode()
    request = Request(
        {
            "type": "http",
            "headers": [(b"x-ms-client-principal", payload.encode())],
        }
    )

    principal = principal_from_request(request)
    assert principal is not None
    assert principal.user_id == "entra-user-1"
    assert principal.user_details == "user@example.com"
