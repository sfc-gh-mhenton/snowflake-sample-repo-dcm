-- Table definitions managed by DCM
-- DCM will CREATE if missing, ALTER if schema changed, leave unchanged if same

DEFINE TABLE {{db}}.SEARCH.KNOWLEDGE_BASE_DCM (
    DOC_ID       NUMBER AUTOINCREMENT PRIMARY KEY,
    TITLE        VARCHAR(500)    NOT NULL,
    CONTENT      TEXT            NOT NULL,
    CATEGORY     VARCHAR(100)    NOT NULL,
    LAST_UPDATED TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Knowledge base for Cortex Search - DCM managed';
