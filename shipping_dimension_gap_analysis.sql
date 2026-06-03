/*
Project: Shipping Dimension Gap Analysis

Business Problem:
Identify products missing shipping dimensions by comparing ecommerce
product records against actual shipment data.

Why This Matters:
Missing or inaccurate shipping dimensions can affect freight rates,
order profitability, and fulfillment accuracy.

Skills Demonstrated:
- Multi-table joins
- Window functions
- Data gap analysis
- Ecommerce operations reporting
- Shipping and fulfillment analytics
*/

WITH shipment_line_items AS (
    SELECT
        order_id,
        sku,
        quantity,
        ROW_NUMBER() OVER (
            PARTITION BY sku
            ORDER BY sku
        ) AS row_num
    FROM shipping_order_line_items
)

SELECT
    catalog.product_id,
    catalog.sku,
    line_items.quantity,
    shipments.shipment_height,
    shipments.shipment_length,
    shipments.shipment_width,
    shipments.shipment_weight_ounces / 16 AS shipment_weight_pounds,
    shipments.order_number,
    shipments.shipped_at

FROM shipment_line_items AS line_items

LEFT JOIN shipments
    ON shipments.order_id = line_items.order_id

LEFT JOIN ecommerce_product_catalog AS catalog
    ON line_items.sku = catalog.sku

WHERE line_items.row_num = 1
  AND catalog.shipping_length IS NULL
  AND catalog.sku IS NOT NULL
  AND line_items.quantity = 1
  AND shipments.shipped_at IS NOT NULL
  AND shipments.order_number NOT LIKE '%.%'

ORDER BY shipments.shipped_at DESC;
