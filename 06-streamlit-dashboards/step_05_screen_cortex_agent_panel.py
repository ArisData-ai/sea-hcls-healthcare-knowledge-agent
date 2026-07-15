# Screen 4: Cortex Agent Conversational Panel for KA_KNOWLEDGE_AGENT.
# Co-authored with CoCo
import streamlit as st
import json
from snowflake.snowpark.context import get_active_session

DB_SCHEMA = "DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE"
AGENT_FQN = "DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE.KA_KNOWLEDGE_AGENT"

# ---------------------------------------------------------------------------
# Session & role
# ---------------------------------------------------------------------------
session = get_active_session()
current_role = session.sql("SELECT CURRENT_ROLE()").collect()[0][0]

# ---------------------------------------------------------------------------
# Session state init
# ---------------------------------------------------------------------------
if "active_queue_id" not in st.session_state:
    st.session_state["active_queue_id"] = None
if "chat_history" not in st.session_state:
    st.session_state["chat_history"] = []

# ---------------------------------------------------------------------------
# Role-gated tab list (now four tabs)
# ---------------------------------------------------------------------------
PRIVILEGED_ROLES = ("ROLE_HK_COMPLIANCE_LEAD", "ROLE_HK_ADMIN", "ACCOUNTADMIN")
AGENT_ROLES = ("ROLE_HK_EXEC_VIEWER", "ROLE_HK_COMPLIANCE_LEAD", "ROLE_HK_ADMIN", "ACCOUNTADMIN")

tab_labels = ["Knowledge Gap & Review Queue", "Content Review Detail"]
if current_role in PRIVILEGED_ROLES:
    tab_labels.append("Compliance & Protocol Oversight")
if current_role in AGENT_ROLES:
    tab_labels.append("Cortex Agent Conversational Panel")

tabs = st.tabs(tab_labels)

# ---------------------------------------------------------------------------
# Screen 1 — Knowledge Gap & Review Queue
# ---------------------------------------------------------------------------
with tabs[0]:
    st.subheader("Knowledge Gap & Review Queue")

    col_f1, col_f2 = st.columns(2)
    with col_f1:
        status_filter = st.multiselect(
            "Status",
            ["Open", "Escalated"],
            default=["Open", "Escalated"],
        )
    with col_f2:
        risk_filter = st.multiselect(
            "Risk Level",
            ["Critical", "High", "Medium", "Low"],
            default=["Critical", "High", "Medium", "Low"],
        )

    if status_filter and risk_filter:
        status_in = ",".join(f"'{s}'" for s in status_filter)
        risk_in = ",".join(f"'{r}'" for r in risk_filter)

        queue_df = session.sql(f"""
            SELECT QUEUE_ID, DOC_TITLE, TRIGGER_TYPE, RISK_LEVEL, STATUS,
                   AGE_DAYS, ASSIGNED_OWNER, TRIGGERING_QUERY_TEXT
            FROM {DB_SCHEMA}.HITL_VW_REVIEW_QUEUE_PRIORITIZED
            WHERE STATUS IN ({status_in})
              AND RISK_LEVEL IN ({risk_in})
        """).to_pandas()
    else:
        queue_df = None

    if queue_df is not None and not queue_df.empty:
        st.dataframe(queue_df, use_container_width=True)

        selected = st.selectbox(
            "Open for review",
            queue_df["QUEUE_ID"].tolist(),
            format_func=lambda qid: f"{qid} — {queue_df.loc[queue_df['QUEUE_ID'] == qid, 'DOC_TITLE'].values[0]}"
            if queue_df.loc[queue_df['QUEUE_ID'] == qid, 'DOC_TITLE'].values[0]
            else qid,
        )
        if st.button("Review selected item") and selected:
            st.session_state["active_queue_id"] = selected
            st.info("Selected — switch to the **Content Review Detail** tab to review.")
    elif queue_df is not None:
        st.info("No items match the current filters.")
    else:
        st.warning("Select at least one Status and one Risk Level to view the queue.")

# ---------------------------------------------------------------------------
# Screen 2 — Content Review Detail
# ---------------------------------------------------------------------------
with tabs[1]:
    st.subheader("Content Review Detail")

    qid = st.session_state.get("active_queue_id")
    if not qid:
        st.warning("Select an item from the Knowledge Gap & Review Queue first.")
    else:
        detail_df = session.sql(f"""
            SELECT * FROM {DB_SCHEMA}.HITL_VW_REVIEW_QUEUE_PRIORITIZED
            WHERE QUEUE_ID = ?
        """, params=[qid]).to_pandas()

        if detail_df.empty:
            st.error(f"Queue item {qid} not found or already closed.")
        else:
            detail = detail_df.iloc[0]

            left, right = st.columns(2)

            with left:
                st.subheader("Triggering Context")
                st.write(f"**Query:** {detail.get('TRIGGERING_QUERY_TEXT', 'N/A')}")
                st.caption(
                    f"Reason: {detail.get('REASON_CODE', 'N/A')}  |  "
                    f"Age: {detail.get('AGE_DAYS', '?')} days  |  "
                    f"Risk: {detail.get('RISK_LEVEL', '?')}"
                )
                st.divider()
                st.subheader("Document Metadata")
                st.write(f"**Title:** {detail.get('DOC_TITLE', 'No linked document')}")
                st.write(f"**Domain:** {detail.get('CONTENT_DOMAIN', 'N/A')}")
                st.write(f"**Department:** {detail.get('OWNING_DEPARTMENT', 'N/A')}")

            with right:
                with st.form("decision_form"):
                    decision = st.selectbox(
                        "Decision",
                        ["No Change", "Minor Update", "Major Revision", "Retired"],
                    )
                    notes = st.text_area("Decision notes")
                    submitted = st.form_submit_button("Submit decision")

                if submitted:
                    doc_ref_key = detail.get("DOC_REF_KEY")
                    try:
                        session.sql(f"""
                            INSERT INTO {DB_SCHEMA}.HITL_TBL_REVIEW_DECISIONS
                                (QUEUE_ID, DOC_REF_KEY, DECISION, DECISION_NOTES)
                            VALUES (?, ?, ?, ?)
                        """, params=[qid, doc_ref_key, decision, notes]).collect()

                        session.sql(f"""
                            UPDATE {DB_SCHEMA}.CURATED_TBL_DOCUMENTS
                            SET STATUS = CASE WHEN ? = 'Retired' THEN 'Archived' ELSE STATUS END,
                                LAST_REVIEWED_DATE = CURRENT_DATE(),
                                NEXT_REVIEW_DATE = CASE WHEN ? != 'Retired'
                                                        THEN DATEADD('month', 6, CURRENT_DATE())
                                                        ELSE NEXT_REVIEW_DATE END
                            WHERE DOC_REF_KEY = ?
                        """, params=[decision, decision, doc_ref_key]).collect()

                        session.sql(f"""
                            UPDATE {DB_SCHEMA}.HITL_TBL_REVIEW_QUEUE
                            SET STATUS = 'Closed', LAST_UPDATED_AT = CURRENT_TIMESTAMP()
                            WHERE QUEUE_ID = ?
                        """, params=[qid]).collect()

                        session.sql(f"""
                            INSERT INTO {DB_SCHEMA}.KA_ACCESS_AUDIT_LOG
                                (EVENT_TYPE, REFERENCE_ID, CONTENT_DOMAIN, EVENT_DETAIL)
                            VALUES (
                                'REVIEW_DECISION',
                                ?,
                                ?,
                                PARSE_JSON(?)
                            )
                        """, params=[
                            qid,
                            detail.get("CONTENT_DOMAIN"),
                            f'{{"decision":"{decision}","doc_ref_key":"{doc_ref_key}"}}'
                        ]).collect()

                        st.session_state["active_queue_id"] = None
                        st.success("Decision recorded successfully.")
                        st.rerun()

                    except Exception as e:
                        st.error(f"Write failed: {e}")

# ---------------------------------------------------------------------------
# Screen 3 — Compliance & Protocol Oversight (role-gated, defense in depth)
# ---------------------------------------------------------------------------
tab_index = 2
if current_role in PRIVILEGED_ROLES:
    with tabs[tab_index]:
        st.subheader("Compliance & Protocol Oversight")

        try:
            kpis = session.sql(f"""
                SELECT MAX(TOTAL_OPEN_COMPLIANCE_FINDINGS) AS OPEN_FINDINGS,
                       MAX(TOTAL_FINE_EXPOSURE_USD)         AS FINE_EXPOSURE,
                       MAX(TOTAL_PROTOCOLS_OVERDUE)         AS OVERDUE_PROTOCOLS
                FROM {DB_SCHEMA}.SV_HEALTHCARE_KNOWLEDGE_OPS
            """).to_pandas().iloc[0]

            k1, k2, k3 = st.columns(3)
            k1.metric("Open Compliance Findings", int(kpis["OPEN_FINDINGS"] or 0))
            k2.metric("Fine Exposure (USD)", f"${int(kpis['FINE_EXPOSURE'] or 0):,}")
            k3.metric("Overdue Protocols", int(kpis["OVERDUE_PROTOCOLS"] or 0))
        except Exception as e:
            st.warning(f"Could not load KPI metrics: {e}")

        st.divider()
        st.subheader("Escalated Items")

        escalations_df = session.sql(f"""
            SELECT * FROM {DB_SCHEMA}.HITL_VW_ESCALATIONS
        """).to_pandas()

        if escalations_df.empty:
            st.info("No escalated items at this time.")
        else:
            st.dataframe(escalations_df, use_container_width=True)

            st.divider()
            st.subheader("Reassign Escalated Item")

            reassign_qid = st.selectbox(
                "Select item to reassign",
                escalations_df["QUEUE_ID"].tolist(),
                key="reassign_selectbox",
            )
            new_owner = st.text_input("New owner (username)", key="reassign_owner")

            if st.button("Reassign") and reassign_qid and new_owner:
                try:
                    session.sql(f"""
                        UPDATE {DB_SCHEMA}.HITL_TBL_REVIEW_QUEUE
                        SET ASSIGNED_OWNER = ?, STATUS = 'Open',
                            LAST_UPDATED_AT = CURRENT_TIMESTAMP()
                        WHERE QUEUE_ID = ?
                    """, params=[new_owner, reassign_qid]).collect()

                    session.sql(f"""
                        INSERT INTO {DB_SCHEMA}.KA_ACCESS_AUDIT_LOG
                            (EVENT_TYPE, REFERENCE_ID, CONTENT_DOMAIN, EVENT_DETAIL)
                        VALUES (
                            'REASSIGNMENT',
                            ?,
                            NULL,
                            PARSE_JSON(?)
                        )
                    """, params=[
                        reassign_qid,
                        f'{{"new_owner":"{new_owner}"}}'
                    ]).collect()

                    st.success(f"Reassigned {reassign_qid} to {new_owner}.")
                    st.rerun()

                except Exception as e:
                    st.error(f"Reassignment failed: {e}")

    tab_index += 1

# ---------------------------------------------------------------------------
# Screen 4 — Cortex Agent Conversational Panel (role-gated)
# ---------------------------------------------------------------------------
if current_role in AGENT_ROLES:
    with tabs[tab_index]:
        st.subheader("Cortex Agent Conversational Panel")
        st.caption("Ask questions about knowledge base content or operational metrics.")

        # Render chat history
        for msg in st.session_state["chat_history"]:
            with st.chat_message(msg["role"]):
                st.markdown(msg["content"])

        # Chat input
        user_input = st.chat_input("Ask the Healthcare Knowledge Agent...")

        if user_input:
            st.session_state["chat_history"].append({"role": "user", "content": user_input})
            with st.chat_message("user"):
                st.markdown(user_input)

            # Build messages payload for DATA_AGENT_RUN
            messages = [{"role": m["role"], "content": m["content"]}
                        for m in st.session_state["chat_history"]]

            with st.chat_message("assistant"):
                with st.spinner("Thinking..."):
                    try:
                        request_body = json.dumps({"messages": messages})
                        result = session.sql(f"""
                            SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
                                '{AGENT_FQN}',
                                PARSE_JSON(?)
                            ) AS RESPONSE
                        """, params=[request_body]).collect()

                        response_json = json.loads(result[0]["RESPONSE"])
                        # Extract text content from the agent response
                        agent_text = ""
                        if "choices" in response_json:
                            for choice in response_json["choices"]:
                                msg_content = choice.get("message", {}).get("content", "")
                                if msg_content:
                                    agent_text += msg_content
                        elif "message" in response_json:
                            agent_text = response_json["message"].get("content", str(response_json))
                        else:
                            agent_text = str(response_json)

                        st.markdown(agent_text)
                        st.session_state["chat_history"].append(
                            {"role": "assistant", "content": agent_text}
                        )

                        # Audit log entry for agent query
                        session.sql(f"""
                            INSERT INTO {DB_SCHEMA}.KA_ACCESS_AUDIT_LOG
                                (EVENT_TYPE, REFERENCE_ID, CONTENT_DOMAIN, EVENT_DETAIL)
                            VALUES (
                                'QUERY_RETRIEVAL',
                                NULL,
                                NULL,
                                PARSE_JSON(?)
                            )
                        """, params=[
                            json.dumps({"query": user_input[:500]})
                        ]).collect()

                    except Exception as e:
                        error_msg = f"Agent call failed: {e}"
                        st.error(error_msg)
                        st.session_state["chat_history"].append(
                            {"role": "assistant", "content": error_msg}
                        )
