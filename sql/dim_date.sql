-- CREATE OR REPLACE TABLE reports.dim_date AS
-- WITH date_spine AS (
--     SELECT
--         *
--     FROM generate_series(
--         DATE '2018-01-01',
--         DATE '2035-12-31',
--         INTERVAL 1 DAY
--     ) AS t(date_day)
-- )

-- SELECT
--     -- Primary Key
--     date_day                                   AS date_key,

--     -- Basic Date Parts
--     EXTRACT(YEAR FROM date_day)                AS year,
--     EXTRACT(QUARTER FROM date_day)             AS quarter,
--     EXTRACT(MONTH FROM date_day)               AS month,
--     EXTRACT(DAY FROM date_day)                 AS day,

--     -- Month Attributes
--     STRFTIME(date_day, '%B')                   AS month_name,
--     STRFTIME(date_day, '%b')                   AS month_name_short,
--     STRFTIME(date_day, '%Y-%m')                AS year_month,

--     -- Week Attributes (ISO-compliant)
--     EXTRACT(WEEK FROM date_day)                AS week_of_year,
--     STRFTIME(date_day, '%G-W%V')               AS iso_year_week,
--     DATE_TRUNC('week', date_day)               AS week_start_date,

--     -- Day Attributes
--     EXTRACT(DOW FROM date_day)                 AS day_of_week,
--     STRFTIME(date_day, '%A')                   AS day_name,
--     STRFTIME(date_day, '%a')                   AS day_name_short,

--     -- Flags
--     CASE WHEN EXTRACT(DOW FROM date_day) IN (0,6) THEN 1 ELSE 0 END
--                                                 AS is_weekend,
--     CASE WHEN date_day = CURRENT_DATE THEN 1 ELSE 0 END
--                                                 AS is_today,

--     -- Period Boundaries
--     DATE_TRUNC('month', date_day)              AS month_start_date,
--     DATE_TRUNC('quarter', date_day)            AS quarter_start_date,
--     DATE_TRUNC('year', date_day)               AS year_start_date

-- FROM date_spine;
