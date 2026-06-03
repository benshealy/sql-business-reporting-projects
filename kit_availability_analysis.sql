/*
Project: Kit Availability Analysis

Business Problem:
Calculate whether a kit product is available for sale based on
the inventory levels of its component items across warehouse locations.

Why This Matters:
Kit products depend on component inventory. If one required component
is unavailable, the full kit may not be sellable even if other components
have stock.

Skills Demonstrated:
- CTEs
- Window functions
- Aggregation
- Inventory analysis
- Kit/component relationships
- Multi-location inventory reporting
*/

WITH component_inventory AS (
    SELECT
        kits.kit_item_number,
        inventory.location_code,
        kits.component_item_number,
        inventory.qty_on_hand,

        MIN(inventory.qty_on_hand) OVER (
            PARTITION BY kits.kit_item_number, inventory.location_code
        ) AS available_kit_quantity

    FROM kit_components AS kits

    LEFT JOIN inventory_quantities AS inventory
        ON inventory.item_number = kits.component_item_number

    WHERE inventory.location_code IN ('WAREHOUSE_1', 'WAREHOUSE_2')
      AND kits.kit_item_number = 'EXAMPLE-KIT-SKU'
),

location_availability AS (
    SELECT
        kit_item_number,
        location_code,
        MAX(available_kit_quantity) AS available_quantity
    FROM component_inventory
    GROUP BY
        kit_item_number,
        location_code
)

SELECT
    kit_item_number,
    SUM(available_quantity) AS total_available_quantity,

    CASE
        WHEN SUM(available_quantity) > 0
            THEN 'In Stock'
        ELSE 'Out of Stock'
    END AS kit_stock_status

FROM location_availability

GROUP BY kit_item_number;
