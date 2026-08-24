def test_retired_barcode_endpoint_is_not_published(client):
    """The retired lookup is absent from both the contract and HTTP router."""

    assert "/api/v1/food-products/barcodes/{barcode}" not in client.app.openapi()["paths"]

    response = client.get("/api/v1/food-products/barcodes/0123456789012")

    assert response.status_code == 404
