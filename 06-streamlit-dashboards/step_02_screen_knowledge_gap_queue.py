# Screen 1: Knowledge Gap & Review Queue with live filters and row selection.
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

    # Build filter clause from controlled option lists (not free-text input)
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
# Screens 2 & 3 — placeholders until step_03 / step_04
# ---------------------------------------------------------------------------
with tabs[1]:
    st.info("Screen 2 placeholder — content arrives in step_03.")

if current_role in PRIVILEGED_ROLES:
    with tabs[2]:
        st.info("Screen 3 placeholder — content arrives in step_04.")
