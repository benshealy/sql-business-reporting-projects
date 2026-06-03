/*
Project: Duplicate Product Detection

Business Problem:
Identify duplicate ecommerce/PIM product records based on shared SKU values.

Why This Matters:
Duplicate product records can create pricing issues, publishing errors,
inventory confusion, and poor customer experience.

Skills Demonstrated:
- Window functions
- COUNT() OVER
- Duplicate detection
- Data quality validation
- Product catalog analysis
*/

SELECT
    product_id,
    parent_product_name,
    sku,
    parent_product_id,
    ecommerce_variant_id,
    COUNT(*) OVER (
        PARTITION BY sku
    ) AS duplicate_count

FROM ecommerce_product_catalog

QUALIFY duplicate_count > 1

ORDER BY parent_product_name ASC, sku;
