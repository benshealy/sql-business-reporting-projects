/*
Project: Product Data Validation

Business Problem:
Identify products that exist in purchasing systems
but are missing from ecommerce/PIM systems.

Why This Matters:
Missing product records create operational delays,
data quality issues, and missing ecommerce listings.

Skills Demonstrated:
- INNER JOIN
- LEFT JOIN
- Filtering
- Cross-system validation
- Data quality analysis
*/

SELECT DISTINCT
    products.item_number,
    products.item_description,
    purchases.vendor_id,
    purchases.promised_date,
    purchases.unit_cost

FROM product_master AS products

INNER JOIN purchase_order_lines AS purchases
    ON products.item_number = purchases.item_number

LEFT JOIN ecommerce_product_catalog AS catalog
    ON products.item_number = catalog.erp_sku

WHERE products.created_date >= '2023-10-01'
AND purchases.purchase_order_status IN
    ('New','Released','Change Order')

AND catalog.erp_sku IS NULL;
