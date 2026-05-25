-- ============================================================================
-- ClearETF Snowflake Intelligence Setup
-- Purpose:
--   Create a Snowflake Intelligence + Cortex Analyst + Cortex Search setup for
--   the existing ClearETF warehouse model in CLEARETF_DB.
--
-- Scope:
--   - Reuses existing structured data in CLEARETF_DB.MARTS and
--     CLEARETF_DB.DIMENSIONS.
--   - Creates a fresh SNOWFLAKE_INTELLIGENCE database for agent objects.
--   - Creates a dedicated warehouse for AI workloads.
--   - Uses only Cortex Analyst and Cortex Search tools.
--   - Excludes CSV uploads, web scraping, email, and Streamlit generation.
--   - Constrains the agent to active UCITS ETF analysis for IFA use cases.
--
-- Repo docs source:
--   https://github.com/dan13g/clear-etf-sf.git
--   Folder copied for search indexing: /docs
-- ============================================================================


-- ============================================================================
-- 0. ACCOUNT-LEVEL SETUP
-- ============================================================================
USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS;

CREATE OR REPLACE ROLE CLEAR_ETF_INTELLIGENCE_ROLE;

SET current_user_name = CURRENT_USER();
GRANT ROLE CLEAR_ETF_INTELLIGENCE_ROLE TO USER IDENTIFIER($current_user_name);

CREATE OR REPLACE WAREHOUSE CLEAR_ETF_INTELLIGENCE_WH
    WITH WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Dedicated warehouse for ClearETF Snowflake Intelligence workloads';

GRANT USAGE ON WAREHOUSE CLEAR_ETF_INTELLIGENCE_WH TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT OPERATE ON WAREHOUSE CLEAR_ETF_INTELLIGENCE_WH TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;

GRANT USAGE ON DATABASE SNOWFLAKE_INTELLIGENCE TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT USAGE ON SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT CREATE AGENT ON SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;

GRANT USAGE ON DATABASE CLEARETF_DB TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT USAGE ON SCHEMA CLEARETF_DB.MARTS TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT USAGE ON SCHEMA CLEARETF_DB.DIMENSIONS TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;

GRANT SELECT ON ALL TABLES IN SCHEMA CLEARETF_DB.MARTS TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA CLEARETF_DB.MARTS TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CLEARETF_DB.MARTS TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA CLEARETF_DB.MARTS TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;

GRANT SELECT ON ALL TABLES IN SCHEMA CLEARETF_DB.DIMENSIONS TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA CLEARETF_DB.DIMENSIONS TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CLEARETF_DB.DIMENSIONS TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA CLEARETF_DB.DIMENSIONS TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;

CREATE SCHEMA IF NOT EXISTS CLEARETF_DB.AI;
GRANT USAGE ON SCHEMA CLEARETF_DB.AI TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT CREATE VIEW ON SCHEMA CLEARETF_DB.AI TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT CREATE TABLE ON SCHEMA CLEARETF_DB.AI TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT CREATE STAGE ON SCHEMA CLEARETF_DB.AI TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT CREATE GIT REPOSITORY ON SCHEMA CLEARETF_DB.AI TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT CREATE CORTEX SEARCH SERVICE ON SCHEMA CLEARETF_DB.AI TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT CREATE SEMANTIC VIEW ON SCHEMA CLEARETF_DB.AI TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;

GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;


-- ============================================================================
-- 1. GIT ACCESS FOR PDF DOCUMENTS IN THE REPO /docs FOLDER
-- ============================================================================
CREATE OR REPLACE API INTEGRATION CLEAR_ETF_GIT_API_INTEGRATION
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = (
        'https://github.com/dan13g/'
    )
    ENABLED = TRUE;

GRANT USAGE ON INTEGRATION CLEAR_ETF_GIT_API_INTEGRATION TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;


-- ============================================================================
-- 2. WORK IN THE AI ROLE
-- ============================================================================
USE ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
USE WAREHOUSE CLEAR_ETF_INTELLIGENCE_WH;
USE DATABASE CLEARETF_DB;
USE SCHEMA AI;


-- ============================================================================
-- 3. REPO + STAGE FOR PDS DOCUMENTS
-- ============================================================================
CREATE OR REPLACE GIT REPOSITORY CLEARETF_REPO
    API_INTEGRATION = CLEAR_ETF_GIT_API_INTEGRATION
    ORIGIN = 'https://github.com/dan13g/clear-etf-sf.git';

ALTER GIT REPOSITORY CLEARETF_REPO FETCH;

CREATE OR REPLACE STAGE INTERNAL_DOCS_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Internal stage holding PDF product disclosure statements copied from the ClearETF GitHub repo docs folder';

COPY FILES
INTO @INTERNAL_DOCS_STAGE/docs/
FROM @CLEARETF_REPO/branches/main/docs/;

ALTER STAGE INTERNAL_DOCS_STAGE REFRESH;


-- ============================================================================
-- 4. HELPER VIEWS TO ENFORCE UCITS-ONLY SCOPE
-- ============================================================================
CREATE OR REPLACE VIEW V_UCITS_ASSET_PRICE_DAILY AS
SELECT
    fact.date_key,
    fact.asset_key,
    fact.full_date,
    fact.open_price,
    fact.high_price,
    fact.low_price,
    fact.close_price,
    fact.adj_close_price,
    fact.volume
FROM CLEARETF_DB.MARTS.FACT_ASSET_PRICE_DAILY AS fact
INNER JOIN CLEARETF_DB.MARTS.DIM_ETF AS etf
    ON fact.asset_key = etf.etf_key
WHERE COALESCE(etf.ucits_flag, FALSE) = TRUE
  AND COALESCE(etf.is_active, TRUE) = TRUE;

CREATE OR REPLACE VIEW V_UCITS_ETF_DAILY AS
SELECT
    fact.date_key,
    fact.etf_key,
    fact.close_price,
    fact.return_1d,
    fact.return_1w,
    fact.return_1m,
    fact.return_3m,
    fact.return_6m,
    fact.return_1y,
    fact.volatility_30d,
    fact.drawdown_52w,
    fact.sharpe_proxy
FROM CLEARETF_DB.MARTS.FACT_ETF_DAILY AS fact
INNER JOIN CLEARETF_DB.MARTS.DIM_ETF AS etf
    ON fact.etf_key = etf.etf_key
WHERE COALESCE(etf.ucits_flag, FALSE) = TRUE
  AND COALESCE(etf.is_active, TRUE) = TRUE;

CREATE OR REPLACE VIEW V_UCITS_ETF_SECTOR AS
SELECT
    bridge.etf_key,
    bridge.sector_key,
    bridge.exposure_weight
FROM CLEARETF_DB.MARTS.BRIDGE_ETF_SECTOR AS bridge
INNER JOIN CLEARETF_DB.MARTS.DIM_ETF AS etf
    ON bridge.etf_key = etf.etf_key
WHERE COALESCE(etf.ucits_flag, FALSE) = TRUE
  AND COALESCE(etf.is_active, TRUE) = TRUE;

CREATE OR REPLACE VIEW V_UCITS_ETF_GEOGRAPHY AS
SELECT
    bridge.etf_key,
    bridge.geography_key,
    bridge.exposure_weight
FROM CLEARETF_DB.MARTS.BRIDGE_ETF_GEOGRAPHY AS bridge
INNER JOIN CLEARETF_DB.MARTS.DIM_ETF AS etf
    ON bridge.etf_key = etf.etf_key
WHERE COALESCE(etf.ucits_flag, FALSE) = TRUE
  AND COALESCE(etf.is_active, TRUE) = TRUE;


-- ============================================================================
-- 5. SEMANTIC VIEW: UCITS ETF PRICE HISTORY
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW CLEARETF_DB.AI.UCITS_ASSET_PRICE_SEMANTIC_VIEW
    TABLES (
        PRICES AS CLEARETF_DB.AI.V_UCITS_ASSET_PRICE_DAILY
            WITH SYNONYMS = ('ucits daily prices', 'ucits asset prices', 'ucits market prices')
            COMMENT = 'Daily OHLCV price fact restricted to active UCITS ETFs',
        DATES AS CLEARETF_DB.DIMENSIONS.DIM_DATE
            PRIMARY KEY (DATE_KEY)
            WITH SYNONYMS = ('calendar', 'trading dates')
            COMMENT = 'Trading calendar dimension',
        ASSETS AS CLEARETF_DB.DIMENSIONS.DIM_ASSET
            PRIMARY KEY (ASSET_KEY)
            WITH SYNONYMS = ('assets', 'instruments', 'securities')
            COMMENT = 'Shared asset dimension',
        ETFS AS CLEARETF_DB.MARTS.DIM_ETF
            PRIMARY KEY (ETF_KEY)
            WITH SYNONYMS = ('ucits etfs', 'funds', 'exchange traded funds')
            COMMENT = 'ETF dimension with UCITS metadata',
        PROVIDERS AS CLEARETF_DB.MARTS.DIM_PROVIDER
            PRIMARY KEY (PROVIDER_KEY)
            WITH SYNONYMS = ('issuers', 'providers')
            COMMENT = 'ETF issuer dimension',
        INDEXES AS CLEARETF_DB.MARTS.DIM_INDEX
            PRIMARY KEY (INDEX_KEY)
            WITH SYNONYMS = ('benchmarks', 'indexes', 'indices')
            COMMENT = 'Benchmark index dimension',
        EQUIVALENCE_GROUPS AS CLEARETF_DB.MARTS.DIM_EQUIVALENCE_GROUP
            PRIMARY KEY (EQUIVALENCE_GROUP_KEY)
            WITH SYNONYMS = ('peer groups', 'equivalence groups')
            COMMENT = 'ETF peer group dimension',
        CLASSIFICATIONS AS CLEARETF_DB.DIMENSIONS.DIM_ASSET_CLASSIFICATION
            PRIMARY KEY (ASSET_KEY)
            WITH SYNONYMS = ('risk buckets', 'trend categories')
            COMMENT = 'Derived asset risk and trend classification'
    )
    RELATIONSHIPS (
        PRICES_TO_DATES AS PRICES(DATE_KEY) REFERENCES DATES(DATE_KEY),
        PRICES_TO_ASSETS AS PRICES(ASSET_KEY) REFERENCES ASSETS(ASSET_KEY),
        PRICES_TO_ETFS AS PRICES(ASSET_KEY) REFERENCES ETFS(ETF_KEY),
        PRICES_TO_CLASSIFICATIONS AS PRICES(ASSET_KEY) REFERENCES CLASSIFICATIONS(ASSET_KEY),
        ETFS_TO_PROVIDERS AS ETFS(PROVIDER_KEY) REFERENCES PROVIDERS(PROVIDER_KEY),
        ETFS_TO_INDEXES AS ETFS(INDEX_KEY) REFERENCES INDEXES(INDEX_KEY),
        ETFS_TO_EQUIVALENCE_GROUPS AS ETFS(EQUIVALENCE_GROUP_KEY) REFERENCES EQUIVALENCE_GROUPS(EQUIVALENCE_GROUP_KEY)
    )
    FACTS (
        PRICES.OPEN_PRICE AS OPEN_PRICE COMMENT = 'Opening price on the trading date',
        PRICES.HIGH_PRICE AS HIGH_PRICE COMMENT = 'High price on the trading date',
        PRICES.LOW_PRICE AS LOW_PRICE COMMENT = 'Low price on the trading date',
        PRICES.CLOSE_PRICE AS CLOSE_PRICE COMMENT = 'Closing price on the trading date',
        PRICES.ADJ_CLOSE_PRICE AS ADJUSTED_CLOSE_PRICE COMMENT = 'Adjusted close price on the trading date',
        PRICES.VOLUME AS VOLUME COMMENT = 'Trading volume on the trading date',
        PRICES.PRICE_RECORD AS 1 COMMENT = 'Count of UCITS ETF daily price records'
    )
    DIMENSIONS (
        DATES.FULL_DATE AS PRICE_DATE
            WITH SYNONYMS = ('date', 'trading date', 'price date')
            COMMENT = 'Trading date of the daily price record',
        DATES.DAY_NAME AS DAY_NAME
            WITH SYNONYMS = ('weekday', 'day')
            COMMENT = 'Day name',
        DATES.WEEK_OF_YEAR AS WEEK_OF_YEAR
            WITH SYNONYMS = ('week', 'calendar week')
            COMMENT = 'Week number',
        DATES.MONTH_NUMBER AS MONTH_NUMBER
            WITH SYNONYMS = ('month number')
            COMMENT = 'Calendar month number',
        DATES.MONTH_NAME AS MONTH_NAME
            WITH SYNONYMS = ('month')
            COMMENT = 'Calendar month name',
        DATES.QUARTER_NUMBER AS QUARTER_NUMBER
            WITH SYNONYMS = ('quarter')
            COMMENT = 'Calendar quarter number',
        DATES.YEAR_NUMBER AS YEAR_NUMBER
            WITH SYNONYMS = ('year')
            COMMENT = 'Calendar year',
        DATES.TRADING_DAY_FLAG AS TRADING_DAY_FLAG
            WITH SYNONYMS = ('trading day', 'market day')
            COMMENT = 'True when the date exists in the tracked market history',
        ETFS.TICKER AS TICKER
            WITH SYNONYMS = ('symbol', 'fund ticker')
            COMMENT = 'ETF ticker',
        ETFS.ETF_CODE AS ETF_CODE
            WITH SYNONYMS = ('fund code', 'etf code')
            COMMENT = 'ETF business code',
        ETFS.ISIN AS ISIN
            WITH SYNONYMS = ('security isin')
            COMMENT = 'ISIN identifier',
        ETFS.FUND_NAME AS FUND_NAME
            WITH SYNONYMS = ('fund', 'fund name', 'etf name')
            COMMENT = 'Fund name',
        ETFS.ASSET_CLASS AS ASSET_CLASS
            WITH SYNONYMS = ('asset class')
            COMMENT = 'Asset class from ETF metadata',
        ETFS.CATEGORY AS ETF_CATEGORY
            WITH SYNONYMS = ('category', 'fund category')
            COMMENT = 'ETF category',
        ETFS.DISTRIBUTION_TYPE AS DISTRIBUTION_TYPE
            WITH SYNONYMS = ('income type', 'distribution')
            COMMENT = 'Accumulating or distributing style',
        ETFS.REPLICATION_METHOD AS REPLICATION_METHOD
            WITH SYNONYMS = ('replication', 'tracking method')
            COMMENT = 'Replication approach',
        ETFS.CURRENCY AS FUND_CURRENCY
            WITH SYNONYMS = ('fund currency', 'quote currency')
            COMMENT = 'Fund currency',
        ETFS.DOMICILE AS DOMICILE
            WITH SYNONYMS = ('fund domicile')
            COMMENT = 'Fund domicile',
        ETFS.HEDGED_FLAG AS HEDGED_FLAG
            WITH SYNONYMS = ('hedged', 'currency hedged')
            COMMENT = 'Currency hedged flag',
        ETFS.UCITS_FLAG AS UCITS_FLAG
            WITH SYNONYMS = ('ucits')
            COMMENT = 'UCITS flag; always true in this semantic view',
        ETFS.TER AS TER
            WITH SYNONYMS = ('ongoing charge', 'expense ratio', 'total expense ratio')
            COMMENT = 'Total expense ratio',
        ETFS.INCEPTION_DATE AS INCEPTION_DATE
            WITH SYNONYMS = ('launch date', 'fund inception')
            COMMENT = 'Fund inception date',
        PROVIDERS.PROVIDER_NAME AS PROVIDER_NAME
            WITH SYNONYMS = ('issuer', 'provider')
            COMMENT = 'ETF issuer name',
        INDEXES.INDEX_NAME AS INDEX_NAME
            WITH SYNONYMS = ('benchmark', 'tracked index')
            COMMENT = 'Benchmark index name',
        INDEXES.INDEX_FAMILY AS INDEX_FAMILY
            WITH SYNONYMS = ('index provider family')
            COMMENT = 'Index family',
        INDEXES.BROAD_REGION_TYPE AS INDEX_REGION_TYPE
            WITH SYNONYMS = ('benchmark region', 'index region')
            COMMENT = 'Broad benchmark region classification',
        EQUIVALENCE_GROUPS.EQUIVALENCE_GROUP_CODE AS EQUIVALENCE_GROUP_CODE
            WITH SYNONYMS = ('peer group code')
            COMMENT = 'ETF peer group code',
        EQUIVALENCE_GROUPS.EQUIVALENCE_GROUP_NAME AS EQUIVALENCE_GROUP_NAME
            WITH SYNONYMS = ('peer group', 'equivalence group')
            COMMENT = 'ETF peer group name',
        EQUIVALENCE_GROUPS.CANONICAL_EXPOSURE AS CANONICAL_EXPOSURE
            WITH SYNONYMS = ('canonical exposure', 'reference exposure')
            COMMENT = 'Canonical exposure of the peer group',
        ASSETS.ASSET_SUBTYPE AS ASSET_SUBTYPE
            WITH SYNONYMS = ('asset subtype')
            COMMENT = 'Underlying asset subtype from the shared asset dimension',
        ASSETS.REGION AS REGION
            WITH SYNONYMS = ('market region')
            COMMENT = 'Primary market region from the shared asset dimension',
        ASSETS.COUNTRY AS COUNTRY
            WITH SYNONYMS = ('market country')
            COMMENT = 'Primary market country from the shared asset dimension',
        ASSETS.EXCHANGE AS EXCHANGE
            WITH SYNONYMS = ('listing exchange')
            COMMENT = 'Listing exchange',
        CLASSIFICATIONS.ROLE AS ROLE
            WITH SYNONYMS = ('portfolio role')
            COMMENT = 'Portfolio role classification',
        CLASSIFICATIONS.RISK_BAND AS RISK_BAND
            WITH SYNONYMS = ('risk level', 'risk band')
            COMMENT = 'Risk band derived from recent volatility',
        CLASSIFICATIONS.VOLATILITY_BUCKET AS VOLATILITY_BUCKET
            WITH SYNONYMS = ('volatility bucket')
            COMMENT = 'Volatility bucket classification',
        CLASSIFICATIONS.DRAWDOWN_BUCKET AS DRAWDOWN_BUCKET
            WITH SYNONYMS = ('drawdown bucket')
            COMMENT = 'Drawdown severity bucket',
        CLASSIFICATIONS.TREND_CATEGORY AS TREND_CATEGORY
            WITH SYNONYMS = ('trend', 'trend label')
            COMMENT = 'Trend classification',
        CLASSIFICATIONS.CORE_SATELLITE_FLAG AS CORE_SATELLITE_FLAG
            WITH SYNONYMS = ('core satellite')
            COMMENT = 'Core versus satellite classification'
    )
    METRICS (
        PRICES.AVERAGE_CLOSE_PRICE AS AVG(PRICES.CLOSE_PRICE)
            COMMENT = 'Average close price',
        PRICES.AVERAGE_ADJUSTED_CLOSE_PRICE AS AVG(PRICES.ADJUSTED_CLOSE_PRICE)
            COMMENT = 'Average adjusted close price',
        PRICES.HIGHEST_TRADED_PRICE AS MAX(PRICES.HIGH_PRICE)
            COMMENT = 'Highest traded price',
        PRICES.LOWEST_TRADED_PRICE AS MIN(PRICES.LOW_PRICE)
            COMMENT = 'Lowest traded price',
        PRICES.TOTAL_VOLUME AS SUM(PRICES.VOLUME)
            COMMENT = 'Total traded volume',
        PRICES.AVERAGE_VOLUME AS AVG(PRICES.VOLUME)
            COMMENT = 'Average traded volume',
        PRICES.TOTAL_PRICE_RECORDS AS COUNT(PRICES.PRICE_RECORD)
            COMMENT = 'Total count of daily price records'
    )
    COMMENT = 'Semantic view for active UCITS ETF daily price history'
    AI_SQL_GENERATION 'This semantic view is already restricted to active UCITS ETFs. Use it for OHLCV, price history, and trading-volume questions. Prefer adjusted close for long-horizon price comparisons across dates. If a user does not specify a date range, default to the latest available 12 months.'
    AI_QUESTION_CATEGORIZATION 'Use this view for UCITS ETF price history, latest price, high-low range, adjusted close, and volume questions.';


-- ============================================================================
-- 6. SEMANTIC VIEW: UCITS ETF RETURNS, RISK, AND EXPOSURE
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW CLEARETF_DB.AI.UCITS_ETF_DAILY_SEMANTIC_VIEW
    TABLES (
        ETF_FACTS AS CLEARETF_DB.AI.V_UCITS_ETF_DAILY
            WITH SYNONYMS = ('ucits etf returns', 'ucits performance', 'ucits etf analytics')
            COMMENT = 'Daily ETF return and risk fact restricted to active UCITS ETFs',
        DATES AS CLEARETF_DB.DIMENSIONS.DIM_DATE
            PRIMARY KEY (DATE_KEY)
            WITH SYNONYMS = ('calendar', 'trading dates')
            COMMENT = 'Trading calendar dimension',
        ETFS AS CLEARETF_DB.MARTS.DIM_ETF
            PRIMARY KEY (ETF_KEY)
            WITH SYNONYMS = ('ucits etfs', 'funds')
            COMMENT = 'ETF dimension with UCITS metadata',
        PROVIDERS AS CLEARETF_DB.MARTS.DIM_PROVIDER
            PRIMARY KEY (PROVIDER_KEY)
            WITH SYNONYMS = ('issuers', 'providers')
            COMMENT = 'ETF issuer dimension',
        INDEXES AS CLEARETF_DB.MARTS.DIM_INDEX
            PRIMARY KEY (INDEX_KEY)
            WITH SYNONYMS = ('benchmarks', 'indexes')
            COMMENT = 'Benchmark index dimension',
        EQUIVALENCE_GROUPS AS CLEARETF_DB.MARTS.DIM_EQUIVALENCE_GROUP
            PRIMARY KEY (EQUIVALENCE_GROUP_KEY)
            WITH SYNONYMS = ('peer groups', 'equivalence groups')
            COMMENT = 'ETF peer group dimension',
        CLASSIFICATIONS AS CLEARETF_DB.DIMENSIONS.DIM_ASSET_CLASSIFICATION
            PRIMARY KEY (ASSET_KEY)
            WITH SYNONYMS = ('risk buckets', 'trend categories')
            COMMENT = 'Derived asset risk and trend classification',
        ETF_SECTORS AS CLEARETF_DB.AI.V_UCITS_ETF_SECTOR
            WITH SYNONYMS = ('sector exposures')
            COMMENT = 'ETF to sector exposure bridge filtered to active UCITS ETFs',
        SECTORS AS CLEARETF_DB.MARTS.DIM_SECTOR
            PRIMARY KEY (SECTOR_KEY)
            WITH SYNONYMS = ('sectors')
            COMMENT = 'Sector dimension',
        ETF_GEOGRAPHIES AS CLEARETF_DB.AI.V_UCITS_ETF_GEOGRAPHY
            WITH SYNONYMS = ('geography exposures', 'regional exposures')
            COMMENT = 'ETF to geography exposure bridge filtered to active UCITS ETFs',
        GEOGRAPHIES AS CLEARETF_DB.MARTS.DIM_GEOGRAPHY
            PRIMARY KEY (GEOGRAPHY_KEY)
            WITH SYNONYMS = ('countries', 'regions', 'geographies')
            COMMENT = 'Geography exposure dimension'
    )
    RELATIONSHIPS (
        ETF_FACTS_TO_DATES AS ETF_FACTS(DATE_KEY) REFERENCES DATES(DATE_KEY),
        ETF_FACTS_TO_ETFS AS ETF_FACTS(ETF_KEY) REFERENCES ETFS(ETF_KEY),
        ETF_FACTS_TO_CLASSIFICATIONS AS ETF_FACTS(ETF_KEY) REFERENCES CLASSIFICATIONS(ASSET_KEY),
        ETFS_TO_PROVIDERS AS ETFS(PROVIDER_KEY) REFERENCES PROVIDERS(PROVIDER_KEY),
        ETFS_TO_INDEXES AS ETFS(INDEX_KEY) REFERENCES INDEXES(INDEX_KEY),
        ETFS_TO_EQUIVALENCE_GROUPS AS ETFS(EQUIVALENCE_GROUP_KEY) REFERENCES EQUIVALENCE_GROUPS(EQUIVALENCE_GROUP_KEY),
        ETFS_TO_SECTOR_BRIDGE AS ETFS(ETF_KEY) REFERENCES ETF_SECTORS(ETF_KEY),
        ETF_SECTORS_TO_SECTORS AS ETF_SECTORS(SECTOR_KEY) REFERENCES SECTORS(SECTOR_KEY),
        ETFS_TO_GEOGRAPHY_BRIDGE AS ETFS(ETF_KEY) REFERENCES ETF_GEOGRAPHIES(ETF_KEY),
        ETF_GEOGRAPHIES_TO_GEOGRAPHIES AS ETF_GEOGRAPHIES(GEOGRAPHY_KEY) REFERENCES GEOGRAPHIES(GEOGRAPHY_KEY)
    )
    FACTS (
        ETF_FACTS.CLOSE_PRICE AS CLOSE_PRICE COMMENT = 'Closing price on the trading date',
        ETF_FACTS.RETURN_1D AS RETURN_1D COMMENT = 'One-day return',
        ETF_FACTS.RETURN_1W AS RETURN_1W COMMENT = 'One-week return',
        ETF_FACTS.RETURN_1M AS RETURN_1M COMMENT = 'One-month return',
        ETF_FACTS.RETURN_3M AS RETURN_3M COMMENT = 'Three-month return',
        ETF_FACTS.RETURN_6M AS RETURN_6M COMMENT = 'Six-month return',
        ETF_FACTS.RETURN_1Y AS RETURN_1Y COMMENT = 'One-year return',
        ETF_FACTS.VOLATILITY_30D AS VOLATILITY_30D COMMENT = 'Thirty-day volatility',
        ETF_FACTS.DRAWDOWN_52W AS DRAWDOWN_52W COMMENT = 'Fifty-two-week drawdown',
        ETF_FACTS.SHARPE_PROXY AS SHARPE_PROXY COMMENT = 'One-year Sharpe proxy',
        ETF_SECTORS.SECTOR_EXPOSURE_WEIGHT AS ETF_SECTORS.EXPOSURE_WEIGHT COMMENT = 'Sector exposure percentage weight',
        ETF_GEOGRAPHIES.GEOGRAPHY_EXPOSURE_WEIGHT AS ETF_GEOGRAPHIES.EXPOSURE_WEIGHT COMMENT = 'Geography exposure percentage weight',
        ETF_FACTS.ETF_RECORD AS 1 COMMENT = 'Count of UCITS ETF daily analytics records'
    )
    DIMENSIONS (
        DATES.FULL_DATE AS OBSERVATION_DATE
            WITH SYNONYMS = ('date', 'observation date', 'trading date')
            COMMENT = 'Trading date of the ETF analytics record',
        DATES.MONTH_NAME AS MONTH_NAME
            WITH SYNONYMS = ('month')
            COMMENT = 'Calendar month name',
        DATES.QUARTER_NUMBER AS QUARTER_NUMBER
            WITH SYNONYMS = ('quarter')
            COMMENT = 'Calendar quarter number',
        DATES.YEAR_NUMBER AS YEAR_NUMBER
            WITH SYNONYMS = ('year')
            COMMENT = 'Calendar year',
        ETFS.TICKER AS TICKER
            WITH SYNONYMS = ('symbol', 'fund ticker')
            COMMENT = 'ETF ticker',
        ETFS.ETF_CODE AS ETF_CODE
            WITH SYNONYMS = ('fund code')
            COMMENT = 'ETF business code',
        ETFS.ISIN AS ISIN
            WITH SYNONYMS = ('security isin')
            COMMENT = 'ISIN identifier',
        ETFS.FUND_NAME AS FUND_NAME
            WITH SYNONYMS = ('fund', 'fund name', 'etf name')
            COMMENT = 'Fund name',
        ETFS.ASSET_CLASS AS ASSET_CLASS
            WITH SYNONYMS = ('asset class')
            COMMENT = 'Asset class from ETF metadata',
        ETFS.CATEGORY AS ETF_CATEGORY
            WITH SYNONYMS = ('category')
            COMMENT = 'ETF category',
        ETFS.DISTRIBUTION_TYPE AS DISTRIBUTION_TYPE
            WITH SYNONYMS = ('distribution', 'income type')
            COMMENT = 'Accumulating or distributing style',
        ETFS.REPLICATION_METHOD AS REPLICATION_METHOD
            WITH SYNONYMS = ('replication')
            COMMENT = 'Replication method',
        ETFS.CURRENCY AS FUND_CURRENCY
            WITH SYNONYMS = ('fund currency')
            COMMENT = 'Fund currency',
        ETFS.DOMICILE AS DOMICILE
            WITH SYNONYMS = ('fund domicile')
            COMMENT = 'Fund domicile',
        ETFS.HEDGED_FLAG AS HEDGED_FLAG
            WITH SYNONYMS = ('hedged')
            COMMENT = 'Currency hedged flag',
        ETFS.UCITS_FLAG AS UCITS_FLAG
            WITH SYNONYMS = ('ucits')
            COMMENT = 'UCITS flag; always true in this semantic view',
        ETFS.TER AS TER
            WITH SYNONYMS = ('expense ratio', 'total expense ratio', 'ongoing charge')
            COMMENT = 'Total expense ratio',
        ETFS.INCEPTION_DATE AS INCEPTION_DATE
            WITH SYNONYMS = ('launch date')
            COMMENT = 'Fund inception date',
        PROVIDERS.PROVIDER_NAME AS PROVIDER_NAME
            WITH SYNONYMS = ('issuer', 'provider')
            COMMENT = 'ETF issuer',
        INDEXES.INDEX_NAME AS INDEX_NAME
            WITH SYNONYMS = ('benchmark', 'tracked index')
            COMMENT = 'Tracked benchmark index',
        INDEXES.INDEX_FAMILY AS INDEX_FAMILY
            WITH SYNONYMS = ('index family')
            COMMENT = 'Index family',
        INDEXES.BROAD_REGION_TYPE AS INDEX_REGION_TYPE
            WITH SYNONYMS = ('benchmark region')
            COMMENT = 'Broad benchmark region classification',
        INDEXES.DEVELOPED_FLAG AS DEVELOPED_FLAG
            WITH SYNONYMS = ('developed markets')
            COMMENT = 'True when the benchmark is classified as developed markets',
        INDEXES.EMERGING_FLAG AS EMERGING_FLAG
            WITH SYNONYMS = ('emerging markets')
            COMMENT = 'True when the benchmark is classified as emerging markets',
        EQUIVALENCE_GROUPS.EQUIVALENCE_GROUP_CODE AS EQUIVALENCE_GROUP_CODE
            WITH SYNONYMS = ('peer group code')
            COMMENT = 'Peer group code',
        EQUIVALENCE_GROUPS.EQUIVALENCE_GROUP_NAME AS EQUIVALENCE_GROUP_NAME
            WITH SYNONYMS = ('peer group')
            COMMENT = 'Peer group name',
        EQUIVALENCE_GROUPS.GROUP_TYPE AS GROUP_TYPE
            WITH SYNONYMS = ('peer group type')
            COMMENT = 'Equivalence group type',
        EQUIVALENCE_GROUPS.CANONICAL_EXPOSURE AS CANONICAL_EXPOSURE
            WITH SYNONYMS = ('canonical exposure')
            COMMENT = 'Canonical exposure',
        CLASSIFICATIONS.ROLE AS ROLE
            WITH SYNONYMS = ('portfolio role')
            COMMENT = 'Portfolio role classification',
        CLASSIFICATIONS.RISK_BAND AS RISK_BAND
            WITH SYNONYMS = ('risk band', 'risk level')
            COMMENT = 'Risk band from recent volatility',
        CLASSIFICATIONS.VOLATILITY_BUCKET AS VOLATILITY_BUCKET
            WITH SYNONYMS = ('volatility bucket')
            COMMENT = 'Volatility bucket',
        CLASSIFICATIONS.DRAWDOWN_BUCKET AS DRAWDOWN_BUCKET
            WITH SYNONYMS = ('drawdown bucket')
            COMMENT = 'Drawdown bucket',
        CLASSIFICATIONS.TREND_CATEGORY AS TREND_CATEGORY
            WITH SYNONYMS = ('trend', 'trend label')
            COMMENT = 'Trend classification',
        CLASSIFICATIONS.CORE_SATELLITE_FLAG AS CORE_SATELLITE_FLAG
            WITH SYNONYMS = ('core satellite')
            COMMENT = 'Core or satellite flag',
        SECTORS.SECTOR_NAME AS SECTOR_NAME
            WITH SYNONYMS = ('sector')
            COMMENT = 'Sector exposure label',
        GEOGRAPHIES.GEOGRAPHY_NAME AS GEOGRAPHY_NAME
            WITH SYNONYMS = ('geography', 'country exposure', 'regional exposure')
            COMMENT = 'Geography exposure label',
        GEOGRAPHIES.GEOGRAPHY_GROUP AS GEOGRAPHY_GROUP
            WITH SYNONYMS = ('geography group', 'region group')
            COMMENT = 'Grouped geography exposure label'
    )
    METRICS (
        ETF_FACTS.AVG_CLOSE_PRICE AS AVG(ETF_FACTS.CLOSE_PRICE)
            COMMENT = 'Average close price',
        ETF_FACTS.AVG_RETURN_1D AS AVG(ETF_FACTS.RETURN_1D)
            COMMENT = 'Average one-day return',
        ETF_FACTS.AVG_RETURN_1M AS AVG(ETF_FACTS.RETURN_1M)
            COMMENT = 'Average one-month return',
        ETF_FACTS.AVG_RETURN_1Y AS AVG(ETF_FACTS.RETURN_1Y)
            COMMENT = 'Average one-year return',
        ETF_FACTS.AVG_VOLATILITY_30D AS AVG(ETF_FACTS.VOLATILITY_30D)
            COMMENT = 'Average thirty-day volatility',
        ETF_FACTS.AVG_DRAWDOWN_52W AS AVG(ETF_FACTS.DRAWDOWN_52W)
            COMMENT = 'Average fifty-two-week drawdown',
        ETF_FACTS.AVG_SHARPE_PROXY AS AVG(ETF_FACTS.SHARPE_PROXY)
            COMMENT = 'Average Sharpe proxy',
        ETF_FACTS.TOTAL_ETF_RECORDS AS COUNT(ETF_FACTS.ETF_RECORD)
            COMMENT = 'Total count of ETF daily analytics records',
        ETF_SECTORS.AVG_SECTOR_EXPOSURE_WEIGHT AS AVG(ETF_SECTORS.SECTOR_EXPOSURE_WEIGHT)
            COMMENT = 'Average sector exposure weight',
        ETF_GEOGRAPHIES.AVG_GEOGRAPHY_EXPOSURE_WEIGHT AS AVG(ETF_GEOGRAPHIES.GEOGRAPHY_EXPOSURE_WEIGHT)
            COMMENT = 'Average geography exposure weight'
    )
    COMMENT = 'Semantic view for active UCITS ETF performance, risk, peer grouping, and exposure analysis'
    AI_SQL_GENERATION 'This semantic view is already restricted to active UCITS ETFs. Use it for return, volatility, drawdown, Sharpe proxy, TER, provider, benchmark, peer-group, and exposure questions. Use sector and geography bridge tables only when the user explicitly asks about exposures or wants to filter the ETF universe by an exposure dimension. When combining exposure tables with performance facts, aggregate performance at ETF and date grain before joining to exposures to avoid fan-out.'
    AI_QUESTION_CATEGORIZATION 'Use this view for UCITS ETF return, risk, fee, issuer, benchmark, peer-group, sector exposure, and geography exposure questions.';


-- ============================================================================
-- 7. PARSE PDS DOCUMENTS FROM THE REPO STAGE
-- ============================================================================
CREATE OR REPLACE TABLE UCITS_PDS_PARSED_CONTENT AS
SELECT
    relative_path,
    UPPER(SPLIT_PART(REGEXP_SUBSTR(relative_path, '[^/]+$'), '.', 1)) AS ticker,
    REGEXP_SUBSTR(relative_path, '[^/]+$') AS title,
    BUILD_STAGE_FILE_URL(@INTERNAL_DOCS_STAGE, relative_path) AS file_url,
    AI_PARSE_DOCUMENT(
        TO_FILE('@INTERNAL_DOCS_STAGE', relative_path),
        {'mode': 'LAYOUT'}
    )::STRING AS content
FROM DIRECTORY(@INTERNAL_DOCS_STAGE)
WHERE relative_path ILIKE 'docs/%.pdf';


-- ============================================================================
-- 8. CORTEX SEARCH SERVICE FOR UCITS ETF PDS DOCUMENTS
-- ============================================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH_UCITS_PDS_DOCS
    ON content
    PRIMARY KEY (relative_path)
    ATTRIBUTES relative_path, file_url, title, ticker
    WAREHOUSE = CLEAR_ETF_INTELLIGENCE_WH
    TARGET_LAG = '1 day'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    COMMENT = 'Semantic search service over UCITS ETF PDS PDFs stored in the repo docs folder'
AS (
    SELECT
        relative_path,
        file_url,
        title,
        ticker,
        content
    FROM UCITS_PDS_PARSED_CONTENT
);


-- ============================================================================
-- 9. CREATE THE UCITS-ONLY IFA AGENT
-- ============================================================================
USE DATABASE SNOWFLAKE_INTELLIGENCE;
USE SCHEMA AGENTS;

CREATE OR REPLACE AGENT UCITS_IFA_ANALYST_AGENT
    COMMENT = 'IFA-focused agent for UCITS ETF analysis using Cortex Analyst and Cortex Search only'
    PROFILE = '{"display_name": "ClearETF UCITS IFA Analyst", "color": "blue"}'
    FROM SPECIFICATION
$$
models:
  orchestration: claude-4-sonnet

orchestration:
  budget:
    seconds: 45
    tokens: 24000

instructions:
  response: "You are an IFA-focused analyst for UCITS ETFs only. Be concise, practical, and evidence-based. If a question falls outside UCITS ETFs, say that it is out of scope and invite the user to ask a UCITS ETF question instead."
  orchestration: "Use Cortex Search first when the user asks about product documentation, disclosures, objectives, risks, investment policy, replication method, or wording from the PDS. Use Cortex Analyst for structured questions about prices, returns, volatility, drawdowns, Sharpe proxy, TER, issuers, benchmarks, peer groups, sectors, and geography exposures. Prefer the ETF analytics semantic view for performance and risk questions, and the price semantic view for OHLCV history. If the user does not specify a date range, default to the latest available 12 months. Do not answer questions about non-UCITS ETFs, single stocks, direct web content, or email tasks."
  sample_questions:
    - question: "Compare VWRP and VUSA on 1Y return, 30D volatility, drawdown, and TER."
    - question: "What is the latest close price and 12 month high-low range for VWRP?"
    - question: "Which UCITS ETF peer group does VUSA belong to?"
    - question: "What does the VWRP PDS say about the fund objective and replication method?"
    - question: "Show the sector and geography exposures for VUSA."

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "Query UCITS ETF Price History"
      description: "Use for UCITS ETF OHLCV history, adjusted close, latest price, and trading volume analysis."
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "Query UCITS ETF Analytics"
      description: "Use for UCITS ETF returns, volatility, drawdowns, Sharpe proxy, TER, benchmark, provider, peer-group, and exposure analysis."
  - tool_spec:
      type: "cortex_search"
      name: "Search UCITS ETF PDS Documents"
      description: "Use for product disclosure statements and other PDF content from the repo docs folder."

tool_resources:
  "Query UCITS ETF Price History":
    semantic_view: "CLEARETF_DB.AI.UCITS_ASSET_PRICE_SEMANTIC_VIEW"
  "Query UCITS ETF Analytics":
    semantic_view: "CLEARETF_DB.AI.UCITS_ETF_DAILY_SEMANTIC_VIEW"
  "Search UCITS ETF PDS Documents":
    name: "CLEARETF_DB.AI.SEARCH_UCITS_PDS_DOCS"
    max_results: "5"
    title_column: "TITLE"
    id_column: "FILE_URL"
$$;


-- ============================================================================
-- 10. GRANTS FOR THE AGENT ROLE
-- ============================================================================
GRANT USAGE ON DATABASE CLEARETF_DB TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT USAGE ON SCHEMA CLEARETF_DB.AI TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA CLEARETF_DB.AI TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA CLEARETF_DB.AI TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT READ ON STAGE CLEARETF_DB.AI.INTERNAL_DOCS_STAGE TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
GRANT USAGE ON CORTEX SEARCH SERVICE CLEARETF_DB.AI.SEARCH_UCITS_PDS_DOCS TO ROLE CLEAR_ETF_INTELLIGENCE_ROLE;


-- ============================================================================
-- 11. VERIFICATION
-- ============================================================================
USE ROLE CLEAR_ETF_INTELLIGENCE_ROLE;
USE WAREHOUSE CLEAR_ETF_INTELLIGENCE_WH;

SHOW SEMANTIC VIEWS IN SCHEMA CLEARETF_DB.AI;
SHOW CORTEX SEARCH SERVICES IN SCHEMA CLEARETF_DB.AI;
SHOW AGENTS IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS;

SELECT COUNT(*) AS parsed_doc_count
FROM CLEARETF_DB.AI.UCITS_PDS_PARSED_CONTENT;

SELECT relative_path, ticker, title
FROM CLEARETF_DB.AI.UCITS_PDS_PARSED_CONTENT
ORDER BY relative_path;
