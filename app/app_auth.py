from __future__ import annotations

import hmac

import streamlit as st

from motherduck_utils import get_setting

AUTH_STATE_KEY = "is_authenticated"


def require_shared_password() -> None:
    configured_password = get_setting("APP_PASSWORD")
    if not configured_password:
        st.title("Market Intel")
        st.error(
            "This app is locked, but `APP_PASSWORD` has not been configured. "
            "Add it to `.streamlit/secrets.toml` locally or your deployment secrets."
        )
        st.stop()

    if st.session_state.get(AUTH_STATE_KEY):
        return

    st.title("Market Intel")
    st.caption("Enter the shared password to continue.")

    with st.form("shared-password-form"):
        password = st.text_input("Password", type="password")
        submitted = st.form_submit_button("Enter")

    if submitted:
        if hmac.compare_digest(password, configured_password):
            st.session_state[AUTH_STATE_KEY] = True
            st.rerun()

        st.error("Incorrect password.")

    st.stop()


def render_logout_button() -> None:
    if st.session_state.get(AUTH_STATE_KEY):
        if st.sidebar.button("Log out"):
            st.session_state[AUTH_STATE_KEY] = False
            st.rerun()
