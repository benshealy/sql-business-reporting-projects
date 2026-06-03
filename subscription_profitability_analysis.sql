/*
Project: Subscription Profitability Analysis

Business Problem:
Analyze active subscription customers by connecting subscription status,
order history, invoice data, pricing, cost, and margin information.

Why This Matters:
Subscription programs can lose profitability when prices, costs, or product
changes are not monitored over time. This query helps identify customer-level
subscription performance and pricing/cost trends.

Skills Demonstrated:
- CTEs
- Window functions
- Customer-level analysis
- Subscription analytics
- Multi-system joins
- Pricing and margin analysis
- Invoice matching
*/

WITH subscriptions AS (
    SELECT
        sub.subscription_id,
        sub.address_id,
        sub.customer_id,
        sub.sku,
        sub.quantity,
        sub.created_at,
        sub.next_charge_scheduled_at,

        CASE
            WHEN sub.next_charge_scheduled_at IS NOT NULL
                 AND sub.next_charge_scheduled_at >= CURRENT_DATE
                 AND sub.sku IS NOT NULL
                THEN 'active'
            ELSE 'inactive'
        END AS subscription_status,

        CASE
            WHEN customer_status.active_subscription_flag = 1
                THEN 'active'
            ELSE 'inactive'
        END AS customer_status,

        ROW_NUMBER() OVER (
            PARTITION BY
                sub.subscription_id,
                sub.address_id,
                sub.customer_id,
                sub.sku
            ORDER BY sub.created_at
        ) AS subscription_rank

    FROM subscription_history AS sub

    LEFT JOIN (
        SELECT
            customer_id,
            MAX(
                CASE
                    WHEN next_charge_scheduled_at IS NOT NULL
                         AND next_charge_scheduled_at >= CURRENT_DATE
                         AND sku IS NOT NULL
                        THEN 1
                    ELSE 0
                END
            ) AS active_subscription_flag
        FROM subscription_history
        GROUP BY customer_id
    ) AS customer_status
        ON sub.customer_id = customer_status.customer_id
),

subscription_orders AS (
    SELECT
        orders.customer_id,
        line_items.purchase_item_id,
        orders.order_id,
        orders.order_type,
        orders.created_at,
        line_items.sku,
        line_items.variant_title,
        line_items.product_title,
        line_items.quantity,
        line_items.shopify_product_id,
        line_items.purchase_item_type,
        line_items.unit_price,
        orders.total_price,
        orders.shopify_order_number,

        ROW_NUMBER() OVER (
            PARTITION BY orders.customer_id
            ORDER BY orders.created_at ASC
        ) AS purchase_rank

    FROM subscription_orders AS orders

    INNER JOIN subscription_order_line_items AS line_items
        ON orders.order_id = line_items.order_id

    INNER JOIN (
        SELECT DISTINCT customer_id
        FROM subscriptions
        WHERE subscription_status = 'active'
    ) AS active_customers
        ON orders.customer_id = active_customers.customer_id

    WHERE line_items.purchase_item_type = 'subscription'
),

invoice_matches AS (
    SELECT
        orders.customer_id,
        orders.order_id AS subscription_order_id,
        orders.shopify_order_id,
        ecommerce_orders.order_id,
        invoices.invoice_number,
        ecommerce_orders.created_date AS initial_order_date,

        ROW_NUMBER() OVER (
            PARTITION BY ecommerce_orders.order_id
            ORDER BY invoices.invoice_number DESC
        ) AS invoice_rank

    FROM subscription_orders AS orders

    INNER JOIN ecommerce_orders
        ON orders.shopify_order_id = ecommerce_orders.order_id

    LEFT JOIN sales_invoices AS invoices
        ON ecommerce_orders.order_number =
           SPLIT_PART(invoices.invoice_number, '.', 1)

    INNER JOIN (
        SELECT DISTINCT customer_id
        FROM subscriptions
        WHERE subscription_status = 'active'
    ) AS active_customers
        ON orders.customer_id = active_customers.customer_id
),

profitability_prep AS (
    SELECT
        invoices.customer_id,
        invoices.subscription_order_id,
        invoices.shopify_order_id,
        invoices.order_id,
        invoices.invoice_number,
        invoices.initial_order_date,

        line_items.sku,
        invoice_lines.item_number,
        line_items.quantity,
        line_items.total_price,
        line_items.unit_price,

        invoice_lines.extended_cost,
        invoice_lines.extended_price,
        invoice_lines.unit_cost,
        invoice_lines.gross_margin_pct,

        MIN(line_items.unit_price) OVER (
            PARTITION BY invoices.customer_id, invoice_lines.item_number
            ORDER BY invoices.initial_order_date
        ) AS initial_price,

        MAX(line_items.unit_price) OVER (
            PARTITION BY invoices.customer_id, invoice_lines.item_number
            ORDER BY invoices.initial_order_date
        ) AS latest_price,

        MIN(invoice_lines.extended_cost) OVER (
            PARTITION BY invoices.customer_id, invoice_lines.item_number
            ORDER BY invoices.initial_order_date
        ) AS initial_cost,

        MAX(invoice_lines.extended_cost) OVER (
            PARTITION BY invoices.customer_id, invoice_lines.item_number
            ORDER BY invoices.initial_order_date DESC
        ) AS latest_cost,

        ROW_NUMBER() OVER (
            PARTITION BY invoices.customer_id
            ORDER BY invoices.initial_order_date
        ) AS customer_order_rank

    FROM invoice_matches AS invoices

    LEFT JOIN subscription_order_line_items AS line_items
        ON invoices.subscription_order_id = line_items.order_id

    INNER JOIN (
        SELECT DISTINCT customer_id
        FROM subscriptions
        WHERE subscription_status = 'active'
    ) AS active_customers
        ON invoices.customer_id = active_customers.customer_id

    INNER JOIN sales_invoice_lines AS invoice_lines
        ON invoices.invoice_number = invoice_lines.invoice_number
       AND line_items.sku = invoice_lines.item_number

    WHERE invoices.invoice_rank = 1
)

SELECT *
FROM profitability_prep
WHERE customer_order_rank = 1
ORDER BY
    customer_id,
    initial_order_date,
    sku;
