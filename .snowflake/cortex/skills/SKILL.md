---
name: healthcare-knowledge-agent-core
description: This skill defines the entry point and orchestration logic for the Healthcare Knowledge Agent, a two-tier Snowflake-native agent that pairs Cortex Search (unstructured retrieval) with Cortex Analyst (structured knowledge-base health analytics) behind a single confidence-plus-currency gate, and routes everything it cannot confidently answer to a four-screen human-in-the-loop review workflow. Use this skill for any task involving agent architecture, workflow sequencing, persona targeting, customer showcasing, orchestration design, or routing implementation work across ingestion, query resolution, structured analytics, human review, governance, platform infrastructure, and Streamlit dashboard modules.
---

# Healthcare Knowledge Agent — Core Skill

## Overview

The Healthcare Knowledge Agent gives care teams, compliance staff, and operations leads one place to ask questions and get answers grounded in the organization's own policies, protocols, and regulatory documents. It pairs two Cortex tools behind a single agent: Cortex Search over the unstructured document library, and Cortex Analyst over a semantic layer that tracks how well that library is being maintained.

The agent is deliberately **agentic but not autonomous**. It acts by routing, flagging, and escalating — deciding whether a question gets answered instantly or handed to a person, and deciding when a stalled review needs to surface to a compliance lead. It never acts by editing content. Every status change to a protocol, policy, or compliance finding is a decision a human enters through the review screens; the agent's job stops at raising the flag and gathering context.

Both tiers are still reactive at the point of use — Tier 1 runs when someone submits a query, Tier 2 runs when someone asks the Cortex Agent a question about knowledge-base health. What makes this version agentic is the layer between them: a governed queue that the agent populates on its own initiative whenever confidence or currency falls short, without waiting for a person to notice the gap first.

**Core Snowflake components used:**

- Cortex Search Service (`KA_KNOWLEDGE_SEARCH`) — unstructured retrieval across the full document corpus
- Cortex Analyst, via semantic view `SV_HEALTHCARE_KNOWLEDGE_OPS` — structured analytics on query throughput, protocol currency, compliance exposure, and coverage health
- A single Cortex Agent binding both tools, with tool-selection instructions distinguishing "answer this clinical/regulatory/operational question" from "tell me about the health of the knowledge base"
- Snowflake Tasks and Streams — orchestrate ingestion, gap detection, and escalation as one pipeline instead of manually run steps
- Streamlit in Snowflake — the four human-in-the-loop screens
- Snowflake Horizon — RBAC, row access policies, and content lineage across both the document layer and the review-queue layer

## When to Use

Use this skill as the starting point for any Healthcare Knowledge Agent implementation task, including:

- Architecture review or re-scoping against the current agent objectives
- Persona identification and stakeholder mapping across all four review screens
- Customer demo planning or AE/SE sales enablement preparation
- Orchestration design (deciding which sibling skill owns which Task, Stream, or table)
- Routing an implementation task to the correct sibling skill file

## Instructions

### Agent Purpose and Positioning

Frame the Healthcare Knowledge Agent as the enterprise knowledge layer that makes clinical, regulatory, and operational content instantly findable, and that never lets a stale or unreviewed answer reach an end user unchecked.

**One-line pitch for customer conversations:**
"This agent answers instantly when it has strong, current evidence — and the moment that evidence gets thin, it routes the question to the right person instead of guessing, so nothing gets fixed or closed out without a human decision."

### The Confidence-Plus-Currency Contract

This is the behavioral core of the agent and every sibling skill inherits it:

    A query gets an instant answer only when BOTH are true:
        1. Cortex Search returns a strong relevance match, AND
        2. The source document is current (not expired, not past its review date,
           not already flagged as a known gap)

    If either condition fails, the agent does not guess. It logs the query as a
    knowledge gap and inserts it into the human review queue with the original
    question and the reason confidence was low.

See `tier1-query-resolution.md` for the gate implementation and `human-in-the-loop-workflow.md` for what happens after a query is routed.

### Target Personas

| Persona                                   | Primary Pain                                         | What They Gain                                                                  | Primary Screen                                      |
| ----------------------------------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------- | --------------------------------------------------- |
| Clinical Informatics / Care Team Leads    | Protocol retrieval is slow and inconsistent          | Instant, governed answers when evidence is strong                               | Query intake (no direct screen access)              |
| Compliance and Regulatory Affairs         | Manual policy lookup consumes analyst time           | On-demand regulatory search with lineage                                        | Query intake; Cortex Agent Conversational Panel     |
| Content Owners (protocol/document owners) | No structured way to know what's stale or gapped     | A prioritized queue and a single decision screen                                | Knowledge Gap & Review Queue; Content Review Detail |
| Quality / Compliance Leads                | No visibility into team workload or escalations      | Oversight of overdue items and reassignment control                             | Compliance & Protocol Oversight                     |
| CTO / Head of Data and AI                 | Knowledge silos and unaudited AI answers create risk | A governed, auditable layer where every answer is either evidenced or escalated | All four screens (admin view)                       |

### Agent Workflow Sequence

The pipeline has two independent entry points that meet in a shared governed layer.

    Step 1: Ingestion
        - Documents land in KA_DOC_STAGE
        - Operational tables (staff roles, document registry, clinical protocols,
          regulatory requirements, compliance findings) are populated separately
          and do not depend on the document pipeline finishing first
        - See knowledge-ingestion-and-indexing.md

    Step 2: Parsing & Chunking
        - AI_PARSE_DOCUMENT (LAYOUT mode) pulls raw text from each staged file
        - SPLIT_TEXT_RECURSIVE_CHARACTER splits into ~1,800-character chunks
          with 300 characters of overlap, then rejoins to document metadata
        - See knowledge-ingestion-and-indexing.md

    Step 3: Indexing
        - Chunks load into Cortex Search Service KA_KNOWLEDGE_SEARCH, filterable
          by content type, department/facility scope, status, and expiry;
          refreshed on a 1-hour target lag
        - See knowledge-ingestion-and-indexing.md

    Step 4: Query Resolution (Tier 1, Reactive)
        - A query comes in; Cortex Search responds; the confidence-plus-currency
          gate decides whether the person gets an answer or a routed knowledge gap
        - See tier1-query-resolution.md

    Step 5: Structured Analytics (Tier 2, Cortex Analyst)
        - Separate path: the semantic view over query metrics, protocol currency,
          and compliance findings answers questions about the health of the
          knowledge base itself, not about clinical content
        - See tier2-structured-analytics.md

    Step 6: Governance write-back
        - Content owners close out reviews (No Change / Minor Update / Major
          Revision / Retired); compliance owners update finding status
        - Nothing here is generated by the agent — these are fields a person
          fills in through the Content Review Detail screen
        - See human-in-the-loop-workflow.md

    Step 7: Downstream analytics and data sharing
        - Coverage and compliance views feed internal dashboards and, where
          configured, get shared to partner organizations via governed
          Snowflake Data Sharing
        - See healthcare-knowledge-governance.md

### Agent Objectives (the behavioral contract every module must honor)

**1. Answer instantly when the evidence actually supports it.** Strong relevance match plus a current source, and only then, is an instant answer returned. Every fast-path interaction is logged so the team can measure self-service rate.

**2. Default to a human the moment the evidence gets thin.** A weak match, or a match from a stale/overdue/already-flagged source, becomes a routed knowledge gap — never a guess. The routed item carries the original question and the reason confidence was insufficient.

**3. Minimize knowledge gaps and compliance exposure over time.** Independent of any single query, every document, protocol, and compliance requirement is continuously scored on recency of review, usage, and ties to open findings. This rolls up into dashboards and a read-only conversational panel. The agent reports what it finds; it never edits a document, changes a protocol, or closes a finding itself.

### How Human Review Works (four connected screens)

Human review is not one step at the end of the pipeline — it is spread across four screens, each built for a different moment:

1. **Knowledge Gap & Review Queue** — every flagged document, overdue protocol, and unresolved question lands here in one prioritized list, oldest/highest-risk first.
2. **Content Review Detail** — the decision screen. Puts the exact queries that triggered the flag next to the document itself. Only a decision made here changes a document's record.
3. **Compliance & Protocol Oversight** — the escalation view. Items unresolved too long, or tied to high-severity findings, surface here automatically for a quality/compliance lead to reassign or take directly.
4. **Cortex Agent Conversational Panel** — read-only. Anyone can ask about trends without ever touching the underlying pipeline.

See `human-in-the-loop-workflow.md` for the data model and `streamlit-dashboard-development.md` for the interface build pattern.

### Demo Path for AEs and SEs

    1. Ingest a sample clinical protocol library (Cortex AI document processing)
    2. Ask a question with strong, current evidence: show the instant answer path
    3. Ask a question the corpus can't confidently support: show it land in the
       Knowledge Gap & Review Queue instead of getting an improvised answer
    4. Open Content Review Detail on that item: show the triggering query next
       to the document, and make a decision (e.g., Minor Update)
    5. Show an overdue, unresolved item auto-escalate into Compliance &
       Protocol Oversight and get reassigned
    6. Ask the Cortex Agent Conversational Panel "what's overdue right now" and
       show the read-only boundary is visible, not just assumed

### Executive Talking Point

Snowflake's Cortex Search and Cortex Analyst eliminate the need for a separate enterprise knowledge management platform or a bolt-on human-review tool — retrieval, structured health scoring, governance, and the review workflow itself all run natively inside the customer's Snowflake account. For governance-sensitive buyers, the differentiator is not that the agent answers questions; it's that the agent is provably unable to act on clinical or regulatory content without a human decision, and that boundary is enforced at the data layer, not just in the UI.

## Coding Conventions

- Database/schema: `DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE` (single-schema pattern; prefixes substitute for schema separation)
- Warehouse: `WH_HCLS_XS`; Role: `ROLE_SCHEMA_HEALTHCARE_KNOWLEDGE` as the base implementation role, with functional sub-roles defined in `healthcare-knowledge-governance.md`
- Object prefix map (mandatory, do not mix):
  - `KA_` document ingestion/indexing pipeline (stages, raw, chunks, search service)
  - `CURATED_TBL_` curated structured business tables
  - `CURATED_VW_` analytical views over curated tables
  - `AI_BI_VW_` / `SV_` semantic base view / semantic view consumed by Cortex Analyst
  - `HITL_TBL_` / `HITL_VW_` human-in-the-loop review queue, decisions, and escalation objects
  - `TASK_` / `STREAM_` orchestration objects, named for the action they perform
- Use 4-space indentation for all SQL, Python, and configuration blocks; no triple backticks in skill file content
- Every new Snowflake object must be traceable to one of the seven workflow steps above — if it doesn't fit, it belongs in a different skill or shouldn't exist yet

## References

- [Ingestion, parsing, chunking, and Cortex Search indexing, orchestrated as one pipeline](references/knowledge-ingestion-and-indexing.md)
- [Tier 1 reactive query resolution: the confidence-plus-currency gate, unified across content domains](references/tier-1-query-resolution.md)
- [Tier 2 structured analytics: the semantic view and Cortex Analyst integration for knowledge-base health](references/tier-2-structured-analytics.md)
- [Human-in-the-loop workflow: the review queue, decision write-back, and escalation logic behind all four screens](references/human-in-the-loop-workflow.md)
- [Healthcare knowledge governance: RBAC, row access, tagging, audit lineage, and data sharing](references/healthcare-knowledge-governance.md)
- [Snowflake platform configuration: warehouses, schema layout, orchestration, and deployment patterns](references/snowflake-knowledge-platform.md)
- [Streamlit dashboard development: building the four interactive human-in-the-loop screens](references/streamlit-dashboard-development.md)
