-- post_deploy.sql
-- Runs AFTER: snow dcm deploy
-- Required env vars: DB, SAMPLE_DB (set by GitHub Actions before envsubst)
-- These objects are NOT supported by DCM DEFINE and must use imperative SQL.

-- =============================================================================
-- SEMANTIC VIEW (not supported by DCM)
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW ${DB}.ANALYTICS.TPCH_SALES_VIEW_DCM

  TABLES (
    orders AS ${SAMPLE_DB}.TPCH_SF1.ORDERS
      PRIMARY KEY (O_ORDERKEY)
      COMMENT = 'Customer orders with status and priority',
    customers AS ${SAMPLE_DB}.TPCH_SF1.CUSTOMER
      PRIMARY KEY (C_CUSTKEY)
      COMMENT = 'Customer master data including market segment',
    line_items AS ${SAMPLE_DB}.TPCH_SF1.LINEITEM
      PRIMARY KEY (L_ORDERKEY, L_LINENUMBER)
      COMMENT = 'Individual line items within orders',
    nations AS ${SAMPLE_DB}.TPCH_SF1.NATION
      PRIMARY KEY (N_NATIONKEY)
      COMMENT = 'Country reference data',
    regions AS ${SAMPLE_DB}.TPCH_SF1.REGION
      PRIMARY KEY (R_REGIONKEY)
      COMMENT = 'Geographic region reference data'
  )

  RELATIONSHIPS (
    orders_to_customers AS orders (O_CUSTKEY) REFERENCES customers,
    line_items_to_orders AS line_items (L_ORDERKEY) REFERENCES orders,
    customers_to_nations AS customers (C_NATIONKEY) REFERENCES nations,
    nations_to_regions AS nations (N_REGIONKEY) REFERENCES regions
  )

  FACTS (
    line_items.extended_price AS L_EXTENDEDPRICE,
    line_items.discount_amount AS L_EXTENDEDPRICE * L_DISCOUNT,
    line_items.net_price AS L_EXTENDEDPRICE * (1 - L_DISCOUNT),
    line_items.taxed_price AS L_EXTENDEDPRICE * (1 - L_DISCOUNT) * (1 + L_TAX)
  )

  DIMENSIONS (
    customers.customer_name AS C_NAME
      WITH SYNONYMS = ('client name', 'account name')
      COMMENT = 'Full name of the customer',
    customers.market_segment AS C_MKTSEGMENT
      COMMENT = 'Market segment: AUTOMOBILE, BUILDING, FURNITURE, HOUSEHOLD, MACHINERY',
    orders.order_date AS O_ORDERDATE
      COMMENT = 'Date the order was placed',
    orders.order_year AS YEAR(O_ORDERDATE)
      COMMENT = 'Year the order was placed',
    orders.order_month AS MONTH(O_ORDERDATE)
      COMMENT = 'Month number when order was placed',
    orders.order_status AS O_ORDERSTATUS
      COMMENT = 'Order status: F=Fulfilled, O=Open, P=Partial',
    orders.order_priority AS O_ORDERPRIORITY
      COMMENT = 'Order priority level',
    nations.nation_name AS N_NAME
      COMMENT = 'Country name',
    regions.region_name AS R_NAME
      COMMENT = 'Geographic region: AFRICA, AMERICA, ASIA, EUROPE, MIDDLE EAST'
  )

  METRICS (
    line_items.total_revenue AS SUM(line_items.net_price)
      COMMENT = 'Total revenue after discounts',
    orders.order_count AS COUNT(O_ORDERKEY)
      COMMENT = 'Number of orders',
    orders.average_order_value AS AVG(O_TOTALPRICE)
      COMMENT = 'Average total order value',
    customers.customer_count AS COUNT(C_CUSTKEY)
      COMMENT = 'Number of unique customers',
    line_items.total_discount AS SUM(line_items.discount_amount)
      COMMENT = 'Total discount amount given',
    line_items.avg_line_price AS AVG(L_EXTENDEDPRICE)
      COMMENT = 'Average extended price per line item'
  )

  COMMENT = 'TPC-H sales analysis (DCM managed) - revenue, orders, and customer metrics'

  AI_SQL_GENERATION 'If no date filter is provided, default to all available data.
    Always round currency values to 2 decimal places.
    When asked about top items, default to top 10 unless specified.
    Order status codes: F=Fulfilled, O=Open, P=Partial.'

  AI_VERIFIED_QUERIES (
    revenue_by_region AS (
      QUESTION 'What is total revenue by region?'
      VERIFIED_AT 1716000000
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = analytics_team)'
      SQL 'SELECT regions.r_name AS region_name, SUM(line_items.l_extendedprice * (1 - line_items.l_discount)) AS total_revenue FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM line_items JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS orders ON line_items.l_orderkey = orders.o_orderkey JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER customers ON orders.o_custkey = customers.c_custkey JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION nations ON customers.c_nationkey = nations.n_nationkey JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION regions ON nations.n_regionkey = regions.r_regionkey GROUP BY regions.r_name ORDER BY total_revenue DESC'
    ),
    top_customers AS (
      QUESTION 'Who are our top 10 customers by revenue?'
      VERIFIED_AT 1716000000
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = analytics_team)'
      SQL 'SELECT customers.c_name AS customer_name, SUM(line_items.l_extendedprice * (1 - line_items.l_discount)) AS total_revenue FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM line_items JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS orders ON line_items.l_orderkey = orders.o_orderkey JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER customers ON orders.o_custkey = customers.c_custkey GROUP BY customers.c_name ORDER BY total_revenue DESC LIMIT 10'
    )
  );

GRANT SELECT, REFERENCES ON SEMANTIC VIEW ${DB}.ANALYTICS.TPCH_SALES_VIEW_DCM TO ROLE CICD_DEPLOYER;

-- =============================================================================
-- CORTEX SEARCH SERVICE (not supported by DCM)
-- =============================================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE ${DB}.SEARCH.KNOWLEDGE_SEARCH_SERVICE_DCM
  ON content
  PRIMARY KEY (doc_id)
  ATTRIBUTES category
  WAREHOUSE = COMPUTE_WH
  TARGET_LAG = '1 hour'
  EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
AS (
  SELECT doc_id, title, content, category, last_updated
  FROM ${DB}.SEARCH.KNOWLEDGE_BASE_DCM
);

GRANT USAGE ON CORTEX SEARCH SERVICE ${DB}.SEARCH.KNOWLEDGE_SEARCH_SERVICE_DCM TO ROLE CICD_DEPLOYER;
