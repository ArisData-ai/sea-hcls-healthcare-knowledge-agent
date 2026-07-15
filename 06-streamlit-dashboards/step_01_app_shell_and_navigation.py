# Streamlit app shell and navigation for the Healthcare Knowledge Agent HITL screens.
# Co-authored with CoCo
import streamlit as st
from snowflake.snowpark.context import get_active_session

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
# Placeholder renderers — replaced by step_02 through step_04
# ---------------------------------------------------------------------------

def render_knowledge_gap_queue():
    st.info("Screen 1 placeholder — content arrives in step_02.")

def render_content_review_detail():
    st.info("Screen 2 placeholder — content arrives in step_03.")

def render_compliance_oversight():
    st.info("Screen 3 placeholder — content arrives in step_04.")

# ---------------------------------------------------------------------------
# Wire tabs to renderers
# ---------------------------------------------------------------------------
with tabs[0]:
    render_knowledge_gap_queue()

with tabs[1]:
    render_content_review_detail()

if current_role in PRIVILEGED_ROLES:
    with tabs[2]:
        render_compliance_oversight()
