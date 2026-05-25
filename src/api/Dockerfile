FROM python:3.12-slim

LABEL com.azure.containerregistry.image.title="ESI Azure AI Proof-of-Concept API"
LABEL com.azure.containerregistry.image.description="FastAPI starter API for Azure AI Foundry, RAG, agent skill lookup, and KPI demos."
LABEL com.azure.containerregistry.image.vendor="ESI AI Solutions Architect Starter Kit"
LABEL com.azure.containerregistry.image.source="https://github.com/replace-with-your-org/esi-ai-solutions-architect-starter"
LABEL com.azure.containerregistry.image.documentation="docs/azure-container-registry.md"
LABEL com.azure.containerregistry.image.licenses="TODO: Confirm license before publishing externally."

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
