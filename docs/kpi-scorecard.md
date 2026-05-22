# KPI Scorecard

Use this scorecard to connect the AI proof of concept to business outcomes. Replace placeholder targets with values from stakeholder discovery.

| KPI | Why It Matters | Starter Target | Measurement Source |
| --- | --- | --- | --- |
| Answer success rate | Shows whether users receive useful responses. | TODO: define with business owner | User feedback and evaluation set |
| Citation coverage | Confirms answers are grounded in approved documents. | TODO: define after RAG implementation | API response metadata |
| Average response time | Measures workflow speed and user experience. | TODO: define based on workflow | Application Insights |
| Human escalation rate | Shows how often the AI cannot confidently help. | TODO: define with subject matter experts | API feedback or ticket handoff |
| Documents uploaded | Tracks data readiness and adoption. | TODO: define by pilot scope | Blob Storage and API telemetry |
| Manual hours saved | Connects the pilot to productivity value. | TODO: define baseline first | Stakeholder reporting |
| Cost per successful answer | Keeps cloud and model usage tied to value. | TODO: define after traffic estimate | Azure Cost Management and API metrics |
| User adoption | Shows whether the workflow is becoming part of normal operations. | TODO: define target audience | Application telemetry |

## Reporting Notes

- Report trends rather than isolated single-day numbers.
- Pair quantitative metrics with user feedback.
- Separate technical health metrics from business value metrics.
- Review cost and quality together; low-cost answers are not useful if they are not trusted.

## Demo Placeholder

The `/metrics` endpoint returns a simple KPI structure so stakeholders can see the measurement plan before the full telemetry pipeline is implemented.
