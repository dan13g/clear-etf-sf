from __future__ import annotations

import streamlit as st

from app_auth import render_logout_button, require_shared_password


st.set_page_config(page_title="About Clear ETF Explorer", layout="wide")


def main() -> None:
    require_shared_password()
    render_logout_button()

    st.title("About Clear ETF Explorer")
    st.caption("What the app does and how to use it.")

    st.subheader("How It Works")
    st.write(
        "Clear ETF Explorer lets you look up a single ETF and view its key metadata, "
        "geographic exposure, sector exposure, and price history in one place."
    )
    st.write(
        "Price history is sourced from the "
        "Yahoo Finance dataset in the warehouse and the chart uses adjusted close price "
        "when it is available."
    )

    st.subheader("How To Use It")
    st.markdown(
        """
        1. Enter an ETF ticker in the search box on the main page.
        2. You can enter a ticker sucj as : `VWRL`;
        3. Click `Load ETF` to fetch the data.
        4. Review the top tables for ETF details, geography, and sectors.
        5. Use the chart range selector to switch between `1M`, `6M`, `1Y`, and `All Time`.
        """
    )

    st.subheader("What You Are Seeing")
    st.markdown(
        """
        - `ETF Info`: core product details such as provider, index, TER, domicile, and UCITS status.
        - `Geography`: the latest available regional exposure weights for the ETF.
        - `Sectors`: the latest available sector exposure weights for the ETF.
        - `Price History`: adjusted close price over time for the selected ETF.
        """
    )

    st.subheader("Notes")
    st.markdown(
        """
        - If an ETF is not found, check that the ticker exists in the underlying dataset.
        - If price history or exposure data is missing, it usually means the source data is incomplete for that ETF.
        """
    )


if __name__ == "__main__":
    main()
