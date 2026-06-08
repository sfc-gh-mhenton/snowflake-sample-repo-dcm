-- SQL Function definitions managed by DCM

DEFINE FUNCTION {{db}}.TOOLS.GET_CUSTOMER_TIER_DCM(CUSTOMER_ID VARCHAR)
  RETURNS VARCHAR
  LANGUAGE SQL
  COMMENT = 'Returns customer tier based on account balance - DCM managed'
AS
$$
  SELECT
    CASE
      WHEN c_acctbal > 9000 THEN 'Enterprise'
      WHEN c_acctbal > 5000 THEN 'Business'
      ELSE 'Starter'
    END
  FROM {{sample_db}}.TPCH_SF1.CUSTOMER
  WHERE c_custkey = CUSTOMER_ID::NUMBER
$$;
