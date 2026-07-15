# Step 04 — Verify Readiness and Preview Test

## Purpose

This is the final verification step for Phase 7. It confirms the agent's
readiness status shows complete in the Snowsight UI and validates correct
tool routing via the Preview tab with two test questions — one targeting
each tool.

---

## Part A: Readiness Checklist Verification

Navigate to the agent in Snowsight:
**Data Products → Cortex AI → Agents → KA_KNOWLEDGE_AGENT → Details**

Confirm ALL readiness steps show as complete (green checkmarks):

| # | Readiness Step | Expected State |
|---|----------------|----------------|
| 1 | Create agent | ✓ Complete |
| 2 | Configure tools | ✓ Complete (2 tools: KnowledgeSearch, KnowledgeOpsAnalyst) |
| 3 | Configure instructions | ✓ Complete (orchestration + response instructions set) |
| 4 | Configure access | ✓ Complete (USAGE granted to ROLE_HK_EXEC_VIEWER, ROLE_HK_COMPLIANCE_LEAD) |
| 5 | Publish version | ✓ Complete (live version set via ALTER AGENT) |

If any step is not checked, note which one and report back before proceeding.

---

## Part B: Preview Tab — Tool Routing Test

Open the **Preview** tab for KA_KNOWLEDGE_AGENT and run both test queries below.
The goal is to confirm the orchestration instructions correctly route each
question to the intended tool.

### Test 1: Content Question → Should Route to KnowledgeSearch

**Query:** "What is the current sepsis protocol?"

**Expected behaviour:**
- The agent invokes the **KnowledgeSearch** tool (Cortex Search)
- The response cites a source document from the knowledge base
- The response does NOT contain SQL or metric aggregations

**Pass criteria:** Tool indicator shows KnowledgeSearch was called; response
contains document-sourced content (protocol steps, policy language, etc.)

---

### Test 2: Metrics Question → Should Route to KnowledgeOpsAnalyst

**Query:** "Which protocols are overdue for review?"

**Expected behaviour:**
- The agent invokes the **KnowledgeOpsAnalyst** tool (Cortex Analyst)
- The response references structured data (counts, lists from the semantic view)
- Under the hood, Cortex Analyst generates SQL against SV_HEALTHCARE_KNOWLEDGE_OPS

**Pass criteria:** Tool indicator shows KnowledgeOpsAnalyst was called; response
contains structured/quantitative information (e.g. protocol names, overdue counts)

---

## Part C: Negative Routing Check (Optional)

If time allows, try one ambiguous question to confirm the orchestration
instruction's tie-breaking rule:

**Query:** "Why does finding the right answer take so long?"

**Expected:** Routes to KnowledgeOpsAnalyst (system performance question),
not KnowledgeSearch.

---

## Confirmation Criteria

Phase 7 step_04 is confirmed when:
1. Readiness shows all steps complete (Part A)
2. Test 1 routes to KnowledgeSearch and returns content (Part B)
3. Test 2 routes to KnowledgeOpsAnalyst and returns metrics (Part B)

Report results for all three. If any test fails (wrong tool selected, error
response, or tool not invoked), report the exact behaviour observed.
