---
name: streamlit-dashboard-development
description: This skill defines how to build the four interactive Streamlit-in-Snowflake screens that serve as the Healthcare Knowledge Agent's human-in-the-loop interface - Knowledge Gap & Review Queue, Content Review Detail, Compliance & Protocol Oversight, and the Cortex Agent Conversational Panel. Use this skill for any task involving Streamlit-in-Snowflake app structure, Snowpark session patterns, interactive widgets bound to live queries, decision-form write-back, reassignment controls, role-gated navigation, or the chat interface for the Cortex Agent. These dashboards must stay interactive, not static reports.
---

# Streamlit Dashboard Development — Skill

## Overview

This skill is dedicated to Streamlit-in-Snowflake specifically, and only Streamlit-in-Snowflake — it is the interface layer for `human-in-the-loop-workflow.md`, not a general BI dashboarding skill. The four screens it builds are not reports; a report can be static, but a review queue that doesn't let someone act on a row, or a conversational panel that doesn't actually converse, fails the job the mockups define. Every screen in this skill must have at least one live interaction: a filter that re-queries, a form that writes back, or a chat turn that calls the agent.

## When to Use

Use this skill for any task involving:

- Building or modifying any of the four human-in-the-loop screens
- Structuring a multi-screen Streamlit-in-Snowflake app (tabs vs. separate apps)
- Writing decision forms that commit to `HITL_TBL_REVIEW_DECISIONS`
- Building the chat interface for the Cortex Agent Conversational Panel
- Role-gating which tab or action a given user sees

## Instructions

### App Structure

One Streamlit-in-Snowflake app, four tabs, shared Snowpark session and shared `st.session_state` — not four separate apps. A content owner moving from the queue to a detail screen needs the selected row to carry over without a page reload outside Streamlit's control.

    import streamlit as st
    from snowflake.snowpark.context import get_active_session

    session = get_active_session()
    current_role = session.sql("SELECT CURRENT_ROLE()").collect()[0][0]

    tab_labels = ["Knowledge Gap & Review Queue", "Content Review Detail",
                  "Compliance & Protocol Oversight", "Cortex Agent Conversational Panel"]
    if current_role not in ("ROLE_HK_COMPLIANCE_LEAD", "ROLE_HK_ADMIN"):
        tab_labels.remove("Compliance & Protocol Oversight")

    tabs = st.tabs(tab_labels)

Role-gating the tab list is a convenience layer only — the row access policies in `healthcare-knowledge-governance.md` are what actually enforce the boundary. Never treat hiding a tab as sufficient access control on its own.

### Screen 1 — Knowledge Gap & Review Queue

    with tabs[0]:
        status_filter = st.multiselect("Status", ["Open", "Escalated"], default=["Open", "Escalated"])
        risk_filter = st.multiselect("Risk Level", ["Critical", "High", "Medium", "Low"],
                                       default=["Critical", "High", "Medium", "Low"])

        queue_df = session.sql(f"""
            SELECT QUEUE_ID, DOC_TITLE, TRIGGER_TYPE, RISK_LEVEL, STATUS,
                   AGE_DAYS, ASSIGNED_OWNER, TRIGGERING_QUERY_TEXT
            FROM HITL_VW_REVIEW_QUEUE_PRIORITIZED
            WHERE STATUS IN ({','.join(f"'{s}'" for s in status_filter)})
              AND RISK_LEVEL IN ({','.join(f"'{r}'" for r in risk_filter)})
        """).to_pandas()

        st.dataframe(queue_df, use_container_width=True)

        selected = st.selectbox("Open for review", queue_df["QUEUE_ID"] if not queue_df.empty else [])
        if st.button("Review selected item") and selected:
            st.session_state["active_queue_id"] = selected
            st.info("Selected — switch to the Content Review Detail tab.")

Filter widgets must re-run the query (not filter a cached static frame) so the screen reflects `HITL_TBL_REVIEW_QUEUE` state as of the moment someone opens it — use `st.cache_data(ttl=60)` at most, never an unbounded cache, since a stale queue is exactly the failure mode this agent exists to prevent elsewhere.

### Screen 2 — Content Review Detail

    with tabs[1]:
        qid = st.session_state.get("active_queue_id")
        if not qid:
            st.warning("Select an item from the Knowledge Gap & Review Queue first.")
        else:
            detail = session.sql(f"""
                SELECT * FROM HITL_VW_REVIEW_QUEUE_PRIORITIZED WHERE QUEUE_ID = '{qid}'
            """).to_pandas().iloc[0]

            left, right = st.columns(2)
            with left:
                st.subheader("What triggered this")
                st.write(detail["TRIGGERING_QUERY_TEXT"])
                st.caption(f"Reason: {detail['REASON_CODE']}  |  Age: {detail['AGE_DAYS']} days")
                st.subheader(detail["DOC_TITLE"])

            with right:
                with st.form("decision_form"):
                    decision = st.selectbox("Decision", ["No Change", "Minor Update",
                                                           "Major Revision", "Retired"])
                    notes = st.text_area("Notes")
                    submitted = st.form_submit_button("Submit decision")

                if submitted:
                    session.sql("""
                        INSERT INTO HITL_TBL_REVIEW_DECISIONS (QUEUE_ID, DOC_REF_KEY, DECISION, DECISION_NOTES)
                        VALUES (?, ?, ?, ?)
                    """, params=[qid, detail["DOC_REF_KEY"], decision, notes]).collect()

                    session.sql("""
                        UPDATE HITL_TBL_REVIEW_QUEUE SET STATUS = 'Closed',
                               LAST_UPDATED_AT = CURRENT_TIMESTAMP() WHERE QUEUE_ID = ?
                    """, params=[qid]).collect()

                    st.success("Decision recorded.")
                    del st.session_state["active_queue_id"]

Every write uses bound parameters (`params=[...]`), never an f-string interpolating `decision` or `notes` directly into SQL — those two fields are free-text user input. Wrap the form in `st.form` so the two writes commit together on one submit, not on every widget interaction.

### Screen 3 — Compliance & Protocol Oversight

    with tabs[2]:
        kpis = session.sql("""
            SELECT MAX(TOTAL_OPEN_COMPLIANCE_FINDINGS) AS OPEN_FINDINGS,
                   MAX(TOTAL_FINE_EXPOSURE_USD) AS FINE_EXPOSURE,
                   MAX(TOTAL_PROTOCOLS_OVERDUE) AS OVERDUE_PROTOCOLS
            FROM SV_HEALTHCARE_KNOWLEDGE_OPS
        """).to_pandas().iloc[0]

        k1, k2, k3 = st.columns(3)
        k1.metric("Open Compliance Findings", int(kpis["OPEN_FINDINGS"] or 0))
        k2.metric("Fine Exposure (USD)", f"${kpis['FINE_EXPOSURE']:,.0f}")
        k3.metric("Overdue Protocols", int(kpis["OVERDUE_PROTOCOLS"] or 0))

        escalations = session.table("HITL_VW_ESCALATIONS").to_pandas()
        st.dataframe(escalations, use_container_width=True)

        row_to_reassign = st.selectbox("Reassign item", escalations["QUEUE_ID"] if not escalations.empty else [])
        new_owner = st.text_input("New owner (username)")
        if st.button("Reassign") and row_to_reassign and new_owner:
            session.sql("""
                UPDATE HITL_TBL_REVIEW_QUEUE SET ASSIGNED_OWNER = ?, STATUS = 'Open'
                WHERE QUEUE_ID = ?
            """, params=[new_owner, row_to_reassign]).collect()
            st.success(f"Reassigned to {new_owner}.")
            st.rerun()

`st.rerun()` after a write is what makes the screen feel live rather than requiring a manual refresh — use it after every mutating action on this tab.

### Screen 4 — Cortex Agent Conversational Panel

    with tabs[3]:
        st.caption("🔒 Read-only — this panel cannot change any document, protocol, or finding.")

        if "chat_history" not in st.session_state:
            st.session_state["chat_history"] = []

        for role, msg in st.session_state["chat_history"]:
            with st.chat_message(role):
                st.write(msg)

        user_msg = st.chat_input("Ask about protocol currency, compliance exposure, or trends...")
        if user_msg:
            st.session_state["chat_history"].append(("user", user_msg))
            with st.chat_message("user"):
                st.write(user_msg)

            with st.chat_message("assistant"):
                response = call_cortex_agent(session, user_msg, role_hint="ROLE_HK_CORTEX_AGENT_ANALYST")
                st.write(response)
            st.session_state["chat_history"].append(("assistant", response))

`call_cortex_agent` must execute under `ROLE_HK_CORTEX_AGENT_ANALYST` or the equivalent search-only role — never under a role that also holds write grants on `HITL_TBL_*` or `CURATED_TBL_*`, even if the calling user themselves happens to be a content owner. The read-only guarantee has to hold regardless of who's logged in.

### Interactivity Checklist (apply to every screen before calling it done)

    - At least one filter or selector that re-queries Snowflake, not a static cached table
    - At least one action (form submit, button, reassignment) that writes back and confirms success
    - Cache TTLs bounded (60s or less) on anything backing a queue or KPI
    - st.rerun() after every mutating action so the screen reflects its own write immediately
    - No custom HTML/JS components — Streamlit-in-Snowflake's sandboxed runtime does not
      support custom components; build with native Streamlit + Snowpark only

## Coding Conventions

- One `.py` app with one function per screen is the default structure; only split into multiple apps if role separation requires it (e.g., a customer wants clinicians to never even load the code behind the review screens)
- Every SQL write from Streamlit uses `session.sql(..., params=[...])` bound parameters — never f-string or `.format()` interpolation of user-entered text into a query string
- Every mutating action gets an explicit `st.success` / `st.error` confirmation — never a silent write
- 4-space indentation for all Python; no triple backticks in skill file content
- Test every screen's click-through path in the Snowsight Streamlit preview before handoff — a screen that renders but whose button silently does nothing is worse than one that visibly errors
