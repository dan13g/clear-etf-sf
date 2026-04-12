from __future__ import annotations

import pandas as pd
import streamlit as st

from app_auth import render_logout_button, require_shared_password
from motherduck_utils import connect_md

DEFAULT_TICKER = "VWRP"
RANGE_OPTIONS = {
    "1M": pd.DateOffset(months=1),
    "6M": pd.DateOffset(months=6),
    "1Y": pd.DateOffset(years=1),
    "All Time": None,
}
ETF_INFO_FIELDS = [
    "Ticker",
    "Fund Name",
    "ISIN",
    "Provider",
    "Index",
    "Index Family",
    "Region",
    "Equivalence Group",
    "Canonical Exposure",
    "Asset Class",
    "Category",
    "Distribution Type",
    "Replication Method",
    "Currency",
    "Domicile",
    "Hedged",
    "UCITS",
    "TER",
    "Inception Date",
    "Active",
]


st.set_page_config(page_title="Clear ETF Explorer", layout="wide")


@st.cache_resource(show_spinner=False)
def get_connection():
    return connect_md()


@st.cache_data(show_spinner=False)
def fetch_etf_metadata(ticker: str) -> pd.DataFrame:
    sql = """
        select
            etf.ticker as "Ticker",
            etf.fund_name as "Fund Name",
            etf.isin as "ISIN",
            provider.provider_name as "Provider",
            idx.index_name as "Index",
            idx.index_family as "Index Family",
            idx.broad_region_type as "Region",
            eq.equivalence_group_name as "Equivalence Group",
            eq.canonical_exposure as "Canonical Exposure",
            etf.asset_class as "Asset Class",
            etf.category as "Category",
            etf.distribution_type as "Distribution Type",
            etf.replication_method as "Replication Method",
            etf.currency as "Currency",
            etf.domicile as "Domicile",
            etf.hedged_flag as "Hedged",
            etf.ucits_flag as "UCITS",
            etf.ter as "TER",
            etf.inception_date as "Inception Date",
            etf.is_active as "Active"
        from marts.dim_etf as etf
        left join marts.dim_provider as provider
            on etf.provider_key = provider.provider_key
        left join marts.dim_index as idx
            on etf.index_key = idx.index_key
        left join marts.dim_equivalence_group as eq
            on etf.equivalence_group_key = eq.equivalence_group_key
        where upper(etf.ticker) = upper(?)
        limit 1
    """
    return get_connection().execute(sql, [ticker]).df()


@st.cache_data(show_spinner=False)
def fetch_geography_exposure(ticker: str) -> pd.DataFrame:
    sql = """
        select
            geography.geography_name as Geography,
            round(bridge.exposure_weight * 100, 2) as "Exposure Weight (%)"
        from marts.bridge_etf_geography as bridge
        inner join marts.dim_etf as etf
            on bridge.etf_key = etf.etf_key
        inner join marts.dim_geography as geography
            on bridge.geography_key = geography.geography_key
        where upper(etf.ticker) = upper(?)
        order by bridge.exposure_weight desc, geography.geography_name
    """
    return get_connection().execute(sql, [ticker]).df()


@st.cache_data(show_spinner=False)
def fetch_sector_exposure(ticker: str) -> pd.DataFrame:
    sql = """
        select
            sector.sector_name as Sector,
            round(bridge.exposure_weight * 100, 2) as "Exposure Weight (%)"
        from marts.bridge_etf_sector as bridge
        inner join marts.dim_etf as etf
            on bridge.etf_key = etf.etf_key
        inner join marts.dim_sector as sector
            on bridge.sector_key = sector.sector_key
        where upper(etf.ticker) = upper(?)
        order by bridge.exposure_weight desc, sector.sector_name
    """
    return get_connection().execute(sql, [ticker]).df()


@st.cache_data(show_spinner=False)
def fetch_price_history(ticker: str) -> pd.DataFrame:
    sql = """
        select
            trading_date,
            coalesce(adj_close_price, close_price) as price_value
        from stg.stg_yfinance
        where upper(ticker) = upper(?)
        order by trading_date
    """
    return get_connection().execute(sql, [ticker]).df()


def format_etf_info(metadata: pd.DataFrame) -> pd.DataFrame:
    row = metadata.iloc[0].copy()

    for column in ["Hedged", "UCITS", "Active"]:
        value = row[column]
        if pd.isna(value):
            row[column] = None
        else:
            row[column] = "Yes" if bool(value) else "No"

    if pd.notna(row["TER"]):
        row["TER"] = f"{row['TER']:.2%}"

    if pd.notna(row["Inception Date"]):
        row["Inception Date"] = pd.to_datetime(row["Inception Date"]).date().isoformat()

    info_table = pd.DataFrame(
        {"Field": ETF_INFO_FIELDS, "Value": [row.get(field) for field in ETF_INFO_FIELDS]}
    )
    return info_table.dropna(subset=["Value"])


def build_price_series(price_history: pd.DataFrame, chart_range: str) -> pd.DataFrame:
    history = price_history.copy()
    history["trading_date"] = pd.to_datetime(history["trading_date"])
    history = history.dropna(subset=["price_value"]).sort_values("trading_date")

    if history.empty:
        return history

    offset = RANGE_OPTIONS[chart_range]
    if offset is not None:
        latest_date = history["trading_date"].max()
        start_date = latest_date - offset
        history = history.loc[history["trading_date"] >= start_date].copy()

    if history.empty:
        return history

    return history.rename(
        columns={"trading_date": "Date", "price_value": "Adjusted Close Price"}
    )[["Date", "Adjusted Close Price"]]


def load_etf_data(ticker: str) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    metadata = fetch_etf_metadata(ticker)
    if metadata.empty:
        return metadata, pd.DataFrame(), pd.DataFrame(), pd.DataFrame()

    geography = fetch_geography_exposure(ticker)
    sectors = fetch_sector_exposure(ticker)
    price_history = fetch_price_history(ticker)
    return metadata, geography, sectors, price_history


def normalize_ticker_input(ticker: str) -> str:
    normalized_ticker = ticker.strip().upper()
    if not normalized_ticker:
        return ""

    if "." in normalized_ticker:
        return normalized_ticker

    return f"{normalized_ticker}.L"


def main() -> None:
    require_shared_password()
    render_logout_button()

    st.title("Clear ETF Explorer")
    st.caption("Search ETF metadata, geography, sectors and performance.")

    if "selected_ticker" not in st.session_state:
        st.session_state.selected_ticker = DEFAULT_TICKER
    if "loaded_ticker" not in st.session_state:
        st.session_state.loaded_ticker = None

    with st.form("ticker-form"):
        ticker_input = st.text_input("ETF ticker", value=st.session_state.selected_ticker)
        submitted = st.form_submit_button("Load ETF")

    if submitted:
        raw_ticker = ticker_input.strip().upper()
        st.session_state.selected_ticker = raw_ticker

        if not raw_ticker:
            st.warning("Enter an ETF ticker to continue.")
            st.stop()

        st.session_state.loaded_ticker = normalize_ticker_input(raw_ticker)

    ticker = st.session_state.loaded_ticker
    if not ticker:
        st.info("Enter a ticker and click `Load ETF`")
        st.stop()

    try:
        metadata, geography, sectors, price_history = load_etf_data(ticker)
    except Exception as exc:
        st.error(
            "Could not query MotherDuck. Make sure `MOTHERDUCK_TOKEN` is set and the database is reachable."
        )
        st.exception(exc)
        st.stop()

    if metadata.empty:
        st.error(f"No ETF found for ticker `{ticker}`.")
        st.stop()

    st.subheader("ETF Info")
    st.dataframe(format_etf_info(metadata), use_container_width=True, hide_index=True)

    left_col, right_col = st.columns(2)

    with left_col:
        st.subheader("Geography")
        if geography.empty:
            st.info("No geography exposure data available.")
        else:
            st.dataframe(geography, use_container_width=True, hide_index=True)

    with right_col:
        st.subheader("Sectors")
        if sectors.empty:
            st.info("No sector exposure data available.")
        else:
            st.dataframe(sectors, use_container_width=True, hide_index=True)

    st.subheader("Price History")
    range_labels = list(RANGE_OPTIONS.keys())
    chart_range = st.radio(
        "Chart range",
        range_labels,
        index=range_labels.index("All Time"),
        horizontal=True,
    )

    if price_history.empty:
        st.info("No price history available for this ETF.")
        return

    price_series = build_price_series(price_history, chart_range)
    if price_series.empty:
        st.info("Not enough price history to draw the chart.")
        return

    st.line_chart(price_series, x="Date", y="Adjusted Close Price", use_container_width=True)


if __name__ == "__main__":
    main()
