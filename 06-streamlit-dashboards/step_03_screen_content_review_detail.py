# Screen 2: Content Review Detail with decision form and three-write transaction.
# Co-authored with CoCo
import streamlit as st
from snowflake.snowpark.context import get_active_session

DB_SCHEMA = "DB_SNOWFLAKE_ENTERPRISE_AGENTS_HCLS.SCHEMA_HEALTHCARE_KNOWLEDGE"

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

# ---------------------------------------------------------------------------
# Role-gated tab list
# ---------------------------------------------------------------------------
PRIVILEGED_ROLES = ("ROLE_HK_COMPLIANCE_LEAD", "ROLE_HK_ADMIN", "ACCOUNTADMIN")

tab_labels = ["Knowledge Gap & Review Queue", "Content Review Detail"]
if current_role in PRIVILEGED_ROLES:
    tab_labels.append("Compliance & Protocol Oversight")

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
                        # 1. Record the decision
                        session.sql(f"""
                            INSERT INTO {DB_SCHEMA}.HITL_TBL_REVIEW_DECISIONS
                                (QUEUE_ID, DOC_REF_KEY, DECISION, DECISION_NOTES)
                            VALUES (?, ?, ?, ?)
                        """, params=[qid, doc_ref_key, decision, notes]).collect()

                        # 2. Update document review dates and status
                        session.sql(f"""
                            UPDATE {DB_SCHEMA}.CURATED_TBL_DOCUMENTS
                            SET STATUS = CASE WHEN ? = 'Retired' THEN 'Archived' ELSE STATUS END,
                                LAST_REVIEWED_DATE = CURRENT_DATE(),
                                NEXT_REVIEW_DATE = CASE WHEN ? != 'Retired'
                                                        THEN DATEADD('month', 6, CURRENT_DATE())
                                                        ELSE NEXT_REVIEW_DATE END
                            WHERE DOC_REF_KEY = ?
                        """, params=[decision, decision, doc_ref_key]).collect()

                        # 3. Close the queue item
                        session.sql(f"""
                            UPDATE {DB_SCHEMA}.HITL_TBL_REVIEW_QUEUE
                            SET STATUS = 'Closed', LAST_UPDATED_AT = CURRENT_TIMESTAMP()
                            WHERE QUEUE_ID = ?
                        """, params=[qid]).collect()

                        # 4. Audit log entry
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
# Screen 3 — placeholder until step_04
# ---------------------------------------------------------------------------
if current_role in PRIVILEGED_ROLES:
    with tabs[2]:
        st.info("Screen 3 placeholder — content arrives in step_04.")
