/*
Project: Kit Inventory Reporting

Business Problem:
Determine available inventory for bundled products
based on component-level inventory quantities.

Why This Matters:
Kit products often cannot be sold if component inventory
is insufficient. This analysis helps identify availability.

Skills Demonstrated:
- Aggregation
- GROUP BY
- SUM()
- JOINs
- Inventory Analysis
*/

SELECT

    kits.kit_item_number,

    SUM(inventory.qty_on_hand)
        AS total_component_inventory

FROM inventory_quantities inventory

LEFT JOIN kit_components kits

    ON inventory.item_number =
       kits.component_item_number

WHERE inventory.location_code = 'MAIN'

AND kits.kit_item_number =
    'EXAMPLE-KIT'

GROUP BY kits.kit_item_number;
