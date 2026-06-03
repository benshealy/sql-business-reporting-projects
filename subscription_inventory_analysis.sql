/*
Project: Subscription Inventory Analysis

Business Problem:
Identify active customer subscriptions with upcoming charges and connect them
to inventory availability and product master data.

Why This Matters:
Helps identify inventory shortages, product issues, and customer impact
before upcoming subscription orders are processed.

Skills Demonstrated:
- CTEs
- Window Functions
- CASE statements
- Data Cleaning
- Multi-table joins
- Business Logic
*/

WITH cleaned_subscriptions AS (

    SELECT
        subscriptions.subscription_id,
        subscriptions.customer_id,
        customers.email,
        subscriptions.address_id,
        subscriptions.status,
        subscriptions.variant_title,
        subscriptions.price,

        CASE
            WHEN POSITION(':' IN subscriptions.sku) > 0
                THEN LEFT(
                    subscriptions.sku,
                    POSITION(':' IN subscriptions.sku) - 1
                )
            ELSE subscriptions.sku
        END AS cleaned_sku,

        CASE
            WHEN POSITION(':' IN subscriptions.sku) > 0
                 AND POSITION('PK' IN subscriptions.sku) > 0
                THEN TRIM(
                    SUBSTRING(
                        subscriptions.sku,
                        POSITION(':' IN subscriptions.sku) + 1,
                        POSITION('PK' IN subscriptions.sku)
                        - POSITION(':' IN subscriptions.sku) - 1
                    )
                )
            ELSE subscriptions.quantity
        END AS order_quantity,

        subscriptions.shopify_product_id,
        subscriptions.shopify_variant_id,
        subscriptions.charge_interval_frequency,
        subscriptions.order_interval_frequency,
        subscriptions.order_interval_unit,
        subscriptions.created_at,
        subscriptions.updated_at,
        subscriptions.next_charge_scheduled_at,

        ROW_NUMBER() OVER (
            PARTITION BY
                subscriptions.customer_id,
                subscriptions.sku
            ORDER BY subscriptions.updated_at DESC
        ) AS row_num

    FROM subscription_history AS subscriptions

    LEFT JOIN customer_accounts AS customers
        ON subscriptions.customer_id = customers.customer_id

    WHERE subscriptions.status = 'active'
      AND subscriptions.next_charge_scheduled_at >= CURRENT_DATE
      AND subscriptions.sku IS NOT NULL
)

SELECT
    cleaned.subscription_id,
    cleaned.customer_id,
    cleaned.email,
    cleaned.address_id,
    cleaned.status,
    cleaned.variant_title,
    cleaned.price,
    cleaned.order_quantity,
    cleaned.shopify_product_id,
    cleaned.shopify_variant_id,
    cleaned.cleaned_sku AS sku,
    inventory.qty_on_hand,
    products.alternate_item_1,
    products.alternate_item_2,
    products.item_description,
    products.item_type,
    cleaned.charge_interval_frequency,
    cleaned.order_interval_frequency,
    cleaned.order_interval_unit,
    cleaned.created_at,
    cleaned.updated_at,
    cleaned.next_charge_scheduled_at

FROM cleaned_subscriptions AS cleaned

LEFT JOIN inventory_quantities AS inventory
    ON cleaned.cleaned_sku = inventory.item_number

LEFT JOIN product_master AS products
    ON cleaned.cleaned_sku = products.item_number

WHERE cleaned.row_num = 1
  AND inventory.location_code = 'MAIN'

ORDER BY cleaned.next_charge_scheduled_at ASC;
