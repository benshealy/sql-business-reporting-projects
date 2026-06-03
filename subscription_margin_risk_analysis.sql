/*
Project: Subscription Margin Risk Analysis

Business Problem:
Identify active subscription products where the subscription price is below
the product cost, creating potential margin loss on upcoming orders.

Why This Matters:
Subscription programs can become unprofitable if product costs increase but
subscription pricing is not updated. This analysis helps identify future
subscription orders with pricing, cost, and inventory risk.

Skills Demonstrated:
- CTEs
- Window functions
- CASE statements
- SKU cleaning
- Multi-table joins
- Product type logic
- Inventory analysis
- Margin risk analysis
*/

WITH kit_inventory AS (
    SELECT DISTINCT
        kit.kit_item_number,
        MIN(inventory.qty_on_hand) OVER (
            PARTITION BY kit.kit_item_number
        ) AS kit_qty_on_hand

    FROM kit_components AS kit

    INNER JOIN inventory_quantities AS inventory
        ON inventory.item_number = kit.component_item_number

    WHERE inventory.location_code = 'MAIN'
),

subscription_analysis AS (
    SELECT
        subscriptions.subscription_id,
        subscriptions.customer_id,
        customers.email,
        subscriptions.sku,
        subscriptions.price AS subscription_price,
        catalog.web_price,
        catalog.variable_cost,
        products.item_description,
        products.item_type,

        CASE
            WHEN LOWER(products.item_type) IN ('kit', 'discontinued')
                 AND kit_inventory.kit_item_number IS NOT NULL
                THEN kit_inventory.kit_qty_on_hand

            WHEN LOWER(products.item_type) = 'discontinued'
                 AND kit_inventory.kit_item_number IS NULL
                THEN inventory.qty_on_hand

            WHEN LOWER(products.item_type) = 'sales inventory'
                THEN inventory.qty_on_hand

            ELSE NULL
        END AS quantity_on_hand,

        subscriptions.next_charge_scheduled_at,
        products.alternate_item_1,
        products.alternate_item_2,

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

        ROW_NUMBER() OVER (
            PARTITION BY subscriptions.customer_id, subscriptions.sku
            ORDER BY subscriptions.next_charge_scheduled_at ASC
        ) AS row_num

    FROM subscription_history AS subscriptions

    LEFT JOIN product_master AS products
        ON CASE
            WHEN POSITION(':' IN subscriptions.sku) > 0
                THEN LEFT(subscriptions.sku, POSITION(':' IN subscriptions.sku) - 1)
            ELSE subscriptions.sku
        END = products.item_number

    LEFT JOIN customer_accounts AS customers
        ON subscriptions.customer_id = customers.customer_id

    LEFT JOIN inventory_quantities AS inventory
        ON CASE
            WHEN POSITION(':' IN subscriptions.sku) > 0
                THEN LEFT(subscriptions.sku, POSITION(':' IN subscriptions.sku) - 1)
            ELSE subscriptions.sku
        END = inventory.item_number

    LEFT JOIN kit_inventory
        ON subscriptions.sku = kit_inventory.kit_item_number

    LEFT JOIN ecommerce_product_catalog AS catalog
        ON subscriptions.sku = catalog.sku

    WHERE subscriptions.next_charge_scheduled_at >= CURRENT_DATE
      AND inventory.location_code = 'MAIN'
)

SELECT
    subscription_id,
    customer_id,
    email,
    sku,
    subscription_price,
    web_price,
    variable_cost,
    item_description,
    item_type,
    quantity_on_hand,
    next_charge_scheduled_at,
    alternate_item_1,
    alternate_item_2,
    order_quantity,

    CASE
        WHEN subscription_price < variable_cost
            THEN 'Margin Risk'
        ELSE 'No Margin Risk'
    END AS margin_risk_flag

FROM subscription_analysis

WHERE row_num = 1
  AND subscription_price < variable_cost

ORDER BY next_charge_scheduled_at ASC;
