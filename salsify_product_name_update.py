"""
Project: Product Name Update Automation

Business Problem:
Update a parent product name and automatically apply consistent naming
to related child/variant products in a PIM/ecommerce platform.

Skills Demonstrated:
- REST API requests
- Authentication headers
- GET and PUT requests
- JSON payloads
- Error handling
- Product/variant data automation

Note:
This example uses placeholder API values and anonymized field names.
"""

import requests


BASE_URL = "https://example-pim-api.com/api/v1"
ORG_ID = "YOUR_ORG_ID_HERE"


def build_headers(token):
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }


def update_product_name(product_id, product_name, headers):
    url = f"{BASE_URL}/orgs/{ORG_ID}/products/{product_id}"

    payload = {
        "Product Name": product_name
    }

    response = requests.put(url, json=payload, headers=headers)

    if response.status_code == 204:
        print(f"Product {product_id} updated successfully.")
    else:
        print(f"Failed to update product {product_id}.")
        print(f"Status code: {response.status_code}")
        print(f"Response: {response.text}")


def get_child_products(parent_id, headers):
    url = (
        f"{BASE_URL}/orgs/{ORG_ID}/products"
        f"?filter=%3D%27parent_id%27%3A%27{parent_id}%27"
    )

    response = requests.get(url, headers=headers)

    if response.status_code != 200:
        print("Failed to retrieve child products.")
        print(f"Status code: {response.status_code}")
        print(f"Response: {response.text}")
        return []

    return response.json().get("data", [])


def main():
    parent_id = input("Enter parent product ID: ")
    new_parent_name = input("Enter new parent product name: ")
    token = input("Enter API token: ")

    headers = build_headers(token)

    update_product_name(parent_id, new_parent_name, headers)

    child_products = get_child_products(parent_id, headers)

    updated_product_ids = []

    for product in child_products:
        product_id = product.get("Product ID")
        variant_name = product.get("variant_name", "N/A")

        if not product_id:
            continue

        updated_child_name = f"{new_parent_name} - {variant_name}"

        update_product_name(product_id, updated_child_name, headers)
        updated_product_ids.append(product_id)

    print("Updated child product IDs:")
    print(updated_product_ids)


if __name__ == "__main__":
    main()
