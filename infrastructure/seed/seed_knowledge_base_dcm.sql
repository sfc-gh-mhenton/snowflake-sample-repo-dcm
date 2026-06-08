-- Seed data for KNOWLEDGE_BASE_DCM
-- Uses MERGE for idempotency - safe to run multiple times
-- Placeholder __DATABASE__ is resolved by resolve_databases.py

MERGE INTO __DATABASE__.SEARCH.KNOWLEDGE_BASE_DCM AS target
USING (
  SELECT column1 AS TITLE, column2 AS CONTENT, column3 AS CATEGORY
  FROM VALUES
    ('Order Fulfillment Process',
     'Orders are fulfilled in the following stages: 1) Order received and validated, 2) Inventory check and reservation, 3) Picking and packing in nearest warehouse, 4) Shipping via preferred carrier based on priority level, 5) Delivery confirmation and invoice generation. Standard orders ship within 3 business days. Priority orders ship within 1 business day.',
     'Operations'),
    ('Customer Segmentation Policy',
     'Customers are segmented into three tiers based on account balance: Enterprise (balance > $9,000) receives dedicated account management, priority shipping, and volume discounts up to 15%. Business ($5,000-$9,000) receives standard support with discounts up to 10%. Starter (< $5,000) receives self-service support with standard pricing. Tier reviews occur quarterly.',
     'Sales Policy'),
    ('Discount Rules and Authorization',
     'Discount authorization levels: Up to 5% - Sales Representative approval. 5-10% - Regional Manager approval required. 10-15% - VP Sales approval required. Above 15% - requires CFO sign-off. Volume discounts are calculated on total order value, not individual line items. Seasonal promotions may override standard limits with executive pre-approval.',
     'Finance Policy'),
    ('Returns and Refund Policy',
     'Returns accepted within 30 days of delivery for manufacturing defects or shipping damage. Customer must obtain RMA number before returning. Refunds processed within 5 business days of receiving returned goods. Restocking fee of 15% applies to non-defective returns. Custom-manufactured parts are non-returnable unless defective.',
     'Operations'),
    ('Regional Sales Strategy 2024',
     'Regional priorities: AMERICA - Focus on expanding Enterprise tier in automotive and machinery segments. EUROPE - Strengthen presence in building materials, target 20% growth. ASIA - New market entry in household segment, establish distribution partnerships. AFRICA - Maintain current accounts, explore furniture segment opportunities. MIDDLE EAST - Premium pricing strategy for machinery and building segments.',
     'Strategy'),
    ('Shipping and Logistics Guidelines',
     'Carrier selection by priority: 1-URGENT uses air freight (2-day delivery). 2-HIGH uses express ground (3-day). 3-MEDIUM and below use standard ground (5-7 days). International shipments require customs documentation prepared by logistics team. Hazardous materials require special handling certification. All shipments over $10,000 require signature confirmation.',
     'Operations')
) AS source(TITLE, CONTENT, CATEGORY)
ON target.TITLE = source.TITLE
WHEN MATCHED THEN
  UPDATE SET
    target.CONTENT = source.CONTENT,
    target.CATEGORY = source.CATEGORY,
    target.LAST_UPDATED = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
  INSERT (TITLE, CONTENT, CATEGORY)
  VALUES (source.TITLE, source.CONTENT, source.CATEGORY);
