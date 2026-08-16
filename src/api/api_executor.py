import ipaddress
import json
import os
import socket
from dataclasses import dataclass
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import HTTPRedirectHandler, Request, build_opener

from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient


MAX_API_RESPONSE_BYTES = 64 * 1024


class _NoRedirectHandler(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def _open_url(request: Request, timeout: int):
    # Redirects are deliberately disabled so an allowlisted public host cannot bounce
    # the executor to a private address or a second, unapproved host.
    return build_opener(_NoRedirectHandler()).open(request, timeout=timeout)


class ApiExecutionError(RuntimeError):
    """A sanitized API-step failure safe to return to the deployment owner."""


@dataclass(frozen=True)
class ApiStepResult:
    step_id: str
    title: str
    status_code: int
    content_type: str
    body: str

    def to_prompt_text(self) -> str:
        return (
            f"API step: {self.title} ({self.step_id})\n"
            f"HTTP status: {self.status_code}\n"
            f"Content-Type: {self.content_type}\n"
            f"Response body:\n{self.body}"
        )


class CredentialResolver:
    def __init__(self) -> None:
        self._credential = DefaultAzureCredential()
        vault_uri = os.getenv("AZURE_KEY_VAULT_URI", "").strip()
        self._secret_client = (
            SecretClient(vault_url=vault_uri, credential=self._credential)
            if vault_uri
            else None
        )

    def resolve(self, reference: str) -> str:
        reference = reference.strip()
        if not reference:
            return ""
        if reference.startswith("env:"):
            value = os.getenv(reference[4:], "")
        elif self._secret_client is not None:
            value = self._secret_client.get_secret(reference).value or ""
        else:
            value = ""
        if not value:
            raise ApiExecutionError(
                f"Credential reference '{reference}' could not be resolved."
            )
        return value


class OutboundApiExecutor:
    def __init__(self, credential_resolver: CredentialResolver | None = None) -> None:
        self.allowed_hosts = {
            host.strip().lower()
            for host in os.getenv("AGENT_API_ALLOWED_HOSTS", "").split(",")
            if host.strip()
        }
        self._credential_resolver = credential_resolver or CredentialResolver()

    def execute(self, step: dict[str, Any], user_input: str) -> ApiStepResult:
        endpoint = str(step.get("endpoint", "")).strip()
        self._validate_url(endpoint)
        method = str(step.get("method", "GET")).upper()
        if method not in {"GET", "POST", "PUT", "PATCH", "DELETE"}:
            raise ApiExecutionError(f"API step uses unsupported method '{method}'.")

        headers = {"Accept": "application/json, text/plain;q=0.9, */*;q=0.5"}
        reference = str(step.get("credentialReference", ""))
        if reference:
            value = self._credential_resolver.resolve(reference)
            header = str(step.get("credentialHeader", "Authorization")).strip()
            scheme = str(step.get("credentialScheme", "Bearer")).strip()
            headers[header] = f"{scheme} {value}".strip()

        data = None
        body_template = str(step.get("requestBodyTemplate", "")).strip()
        if method in {"POST", "PUT", "PATCH", "DELETE"}:
            rendered = body_template.replace("{{input}}", user_input)
            if not rendered:
                rendered = json.dumps({"input": user_input})
            data = rendered.encode("utf-8")
            headers["Content-Type"] = "application/json"

        request = Request(endpoint, data=data, method=method, headers=headers)
        try:
            with _open_url(request, timeout=20) as response:
                status = response.status
                content_type = response.headers.get("Content-Type", "")
                body = response.read(MAX_API_RESPONSE_BYTES + 1)
        except HTTPError as error:
            status = error.code
            content_type = error.headers.get("Content-Type", "")
            body = error.read(MAX_API_RESPONSE_BYTES + 1)
        except (URLError, TimeoutError) as error:
            raise ApiExecutionError(
                f"API step '{step.get('title', step.get('id', 'API'))}' could not be reached."
            ) from error

        truncated = len(body) > MAX_API_RESPONSE_BYTES
        decoded = body[:MAX_API_RESPONSE_BYTES].decode("utf-8", errors="replace")
        if truncated:
            decoded += "\n[response truncated at 64 KiB]"
        return ApiStepResult(
            step_id=str(step.get("id", "api")),
            title=str(step.get("title", "API call")),
            status_code=status,
            content_type=content_type,
            body=decoded,
        )

    def validate(self, step: dict[str, Any]) -> None:
        self._validate_url(str(step.get("endpoint", "")).strip())
        method = str(step.get("method", "GET")).upper()
        if method not in {"GET", "POST", "PUT", "PATCH", "DELETE"}:
            raise ApiExecutionError(f"API step uses unsupported method '{method}'.")

    def _validate_url(self, endpoint: str) -> None:
        parsed = urlparse(endpoint)
        hostname = (parsed.hostname or "").lower()
        if parsed.scheme != "https" or not hostname or parsed.username or parsed.password:
            raise ApiExecutionError("API endpoints must be credential-free HTTPS URLs.")
        if not self._host_allowed(hostname):
            raise ApiExecutionError(
                f"API host '{hostname}' is not in AGENT_API_ALLOWED_HOSTS."
            )
        try:
            addresses = {
                result[4][0]
                for result in socket.getaddrinfo(hostname, parsed.port or 443)
            }
        except socket.gaierror as error:
            raise ApiExecutionError(f"API host '{hostname}' could not be resolved.") from error
        if not addresses or any(not ipaddress.ip_address(address).is_global for address in addresses):
            raise ApiExecutionError("API endpoints must resolve only to public IP addresses.")

    def _host_allowed(self, hostname: str) -> bool:
        return any(
            hostname == allowed
            or (allowed.startswith("*.") and hostname.endswith(allowed[1:]))
            for allowed in self.allowed_hosts
        )
