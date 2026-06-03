/*
Project: Subscription Inventory Analysis

Business Problem:
Identify active customer subscriptions and connect them
to inventory availability and product master data.

Why This Matters:
Helps identify inventory shortages, product issues,
and customer impact before subscription failures occur.

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

        CASE
            WHEN POSITION(':' IN subscriptions.sku) > 0
            THEN LEFT(
                subscriptions.sku,
                POSITION(':' IN subscriptions.sku)-1
            )

            ELSE subscriptions.sku

        END AS cleaned_sku,

        CASE

            WHEN POSITION('PK' IN subscriptions.sku) > 0

            THEN TRIM(
                SUBSTRING(
                    subscriptions.sku,
                    POSITION(':' IN subscriptions.sku)+1,
                    POSITION('PK' IN subscriptions.sku)
                    - POSITION(':' IN subscriptions.sku)-1
                )
            )

            ELSE subscriptions.quantity

        END AS order_quantity,

        ROW_NUMBER() OVER(

            PARTITION BY subscriptions.customer_id,
                         subscriptions.sku

            ORDER BY subscriptions.updated_at DESC

        ) AS row_num

    FROM subscription_history subscriptions

    LEFT JOIN customer_accounts customers
        ON subscriptions.customer_id =
           customers.customer_id

    WHERE subscriptions.status='active'

)

SELECT

    cleaned.subscription_id,
    cleaned.customer_id,
    cleaned.email,
    cleaned.cleaned_sku,

    inventory.qty_on_hand,

    products.item_description,

    cleaned.order_quantity

FROM cleaned_subscriptions cleaned

LEFT JOIN inventory_quantities inventory
    ON cleaned.cleaned_sku =
       inventory.item_number

LEFT JOIN product_master products
    ON cleaned.cleaned_sku =
       products.item_number

WHERE cleaned.row_num = 1;
