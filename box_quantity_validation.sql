/*
Project: Box Quantity Validation

Business Problem:
Compare package quantity values between an internal product system
and an ecommerce/PIM product catalog.

Why This Matters:
Incorrect box, bag, or single-unit quantities can cause pricing errors,
inventory issues, and inaccurate product listings.

Skills Demonstrated:
- Cross-system data validation
- CASE statements
- String parsing
- Multi-table joins
- Data quality flagging
*/

WITH catalog_products AS (
    SELECT
        product_id,
        sku AS catalog_sku,
        product_name,
        parent_product_name,
        quantity AS catalog_quantity,

        CASE
            WHEN POSITION(':' IN sku) > 0
                THEN LEFT(sku, POSITION(':' IN sku) - 1)
            ELSE sku
        END AS base_sku
    FROM ecommerce_product_catalog
    WHERE manufacturer = 'Example Manufacturer'
),

quantity_comparison AS (
    SELECT
        products.sku,
        catalog.catalog_sku,
        catalog.product_id,
        catalog.product_name,
        catalog.parent_product_name,
        products.box_quantity,
        products.bag_quantity,
        catalog.catalog_quantity,

        CASE
            WHEN catalog.product_name ILIKE '%Box%'
                THEN products.box_quantity
            WHEN catalog.product_name ILIKE '%Bag%'
                THEN products.bag_quantity
            WHEN catalog.product_name ILIKE '%Single%'
                THEN 1
            ELSE NULL
        END AS internal_quantity,

        CASE
            WHEN purchase_orders.purchase_order_id IS NOT NULL
                THEN 'Yes'
            ELSE 'No'
        END AS has_purchase_order

    FROM internal_products AS products

    LEFT JOIN catalog_products AS catalog
        ON products.sku = catalog.base_sku

    LEFT JOIN purchase_order_lines AS purchase_orders
        ON products.sku = purchase_orders.item_number
)

SELECT DISTINCT
    sku,
    catalog_sku,
    product_id,
    product_name,
    parent_product_name,
    box_quantity,
    bag_quantity,
    catalog_quantity,
    internal_quantity,

    CASE
        WHEN catalog_quantity = internal_quantity
            THEN 'TRUE'
        ELSE 'FALSE'
    END AS quantity_matches,

    has_purchase_order

FROM quantity_comparison

ORDER BY sku ASC;
