# Smart Cashier API Documentation

## Overview

RESTful API for Smart Cashier (Kasir Cerdas) application with AI-powered product recommendations.

**Base URL:** `http://localhost:8000/api`

**Authentication:** Bearer Token (Laravel Sanctum)

## Authentication

### Login

```http
POST /api/login
Content-Type: application/json

{
  "email": "admin@kasir.com",
  "password": "password"
}
```

**Response:**

```json
{
  "success": true,
  "token": "1|abc123...",
  "user": {
    "id": 1,
    "name": "Administrator",
    "email": "admin@kasir.com",
    "role": "admin"
  }
}
```

### Logout

```http
POST /api/logout
Authorization: Bearer {token}
```

### Refresh Token

```http
POST /api/refresh
Authorization: Bearer {token}
```

## Products API

### Get Products

```http
GET /api/products
Authorization: Bearer {token}
```

**Query Parameters:**

- `search` - Search by name or barcode
- `category_id` - Filter by category
- `active` - Filter active products (true/false)
- `low_stock` - Show only low stock products (true)
- `per_page` - Items per page (default: 15)

### Create Product

```http
POST /api/products
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "Nasi Putih",
  "barcode": "10000001",
  "category_id": 1,
  "price": 5000,
  "cost_price": 3000,
  "stock_quantity": 100,
  "min_stock_level": 10,
  "description": "Nasi putih berkualitas",
  "is_active": true
}
```

### Search by Barcode

```http
POST /api/products/search/barcode
Authorization: Bearer {token}
Content-Type: application/json

{
  "barcode": "10000001"
}
```

### Update Stock

```http
PATCH /api/products/{id}/stock
Authorization: Bearer {token}
Content-Type: application/json

{
  "quantity": 10,
  "type": "in",
  "reason": "Restock"
}
```

## Sales API

### Create Sale

```http
POST /api/sales
Authorization: Bearer {token}
Content-Type: application/json

{
  "customer_id": 1,
  "items": [
    {
      "product_id": 1,
      "quantity": 2,
      "unit_price": 5000,
      "discount": 0
    }
  ],
  "discount_amount": 0,
  "tax_amount": 500,
  "notes": "Customer request"
}
```

### Process Payment

```http
POST /api/sales/{id}/payment
Authorization: Bearer {token}
Content-Type: application/json

{
  "method": "cash",
  "amount": 10500,
  "reference_number": null
}
```

### Get Receipt

```http
GET /api/sales/{id}/receipt
Authorization: Bearer {token}
```

## Customers API

### Get Customers

```http
GET /api/customers
Authorization: Bearer {token}
```

**Query Parameters:**

- `search` - Search by name, email, phone
- `has_membership` - Filter members only
- `tier` - Filter by membership tier (Bronze/Silver/Gold/Platinum)

### Create Customer

```http
POST /api/customers
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "John Doe",
  "email": "john@example.com",
  "phone": "081234567890",
  "membership_id": "MEM001"
}
```

### Add Points

```http
POST /api/customers/{id}/points/add
Authorization: Bearer {token}
Content-Type: application/json

{
  "points": 10
}
```

## AI Recommendations API

### Get Recommendations

```http
GET /api/recommendations?customer_id=1&limit=5
Authorization: Bearer {token}
```

### Generate Recommendations

```http
POST /api/recommendations/generate
Authorization: Bearer {token}
Content-Type: application/json

{
  "customer_id": 1
}
```

### Frequently Bought Together

```http
GET /api/recommendations/frequent-together?product_id=1&limit=3
Authorization: Bearer {token}
```

### Trending Products

```http
GET /api/recommendations/trending?days=30&limit=10
Authorization: Bearer {token}
```

## Dashboard API

### Get Dashboard Stats

```http
GET /api/dashboard/stats
Authorization: Bearer {token}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "today_sales": 25,
    "today_revenue": 150000,
    "total_products": 150,
    "low_stock_products": 5,
    "total_customers": 45,
    "pending_payments": 3
  }
}
```

### Daily Report

```http
GET /api/reports/daily?date=2024-01-15
Authorization: Bearer {token}
```

## Categories API

### Get Categories

```http
GET /api/categories
Authorization: Bearer {token}
```

## Inventory Movements

### Get Movements

```http
GET /api/inventory/movements
Authorization: Bearer {token}
```

**Query Parameters:**

- `type` - Filter by movement type (in/out/sale/adjustment)
- `days` - Recent movements (default: 30)
- `per_page` - Items per page

## Error Responses

All endpoints return errors in this format:

```json
{
  "success": false,
  "message": "Error description",
  "errors": {
    "field": ["Validation error messages"]
  }
}
```

## HTTP Status Codes

- `200` - Success
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `422` - Validation Error
- `500` - Internal Server Error

## Rate Limiting

API endpoints are rate limited. Default limits:

- General endpoints: 60 requests per minute
- Authentication: 5 attempts per minute

## Data Formats

- All dates are in ISO 8601 format (YYYY-MM-DDTHH:mm:ssZ)
- Monetary values are in cents (divide by 100 for display)
- Boolean fields use true/false
- All responses include `success` field

## Sample Usage

### Complete Sale Flow

1. **Login**

```bash
curl -X POST http://localhost:8000/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@kasir.com","password":"password"}'
```

2. **Create Sale**

```bash
curl -X POST http://localhost:8000/api/sales \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": 1,
    "items": [{"product_id": 1, "quantity": 2, "unit_price": 5000}],
    "discount_amount": 0,
    "tax_amount": 500
  }'
```

3. **Process Payment**

```bash
curl -X POST http://localhost:8000/api/sales/{sale_id}/payment \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"method":"cash","amount":10500}'
```

4. **Get Receipt**

```bash
curl -X GET http://localhost:8000/api/sales/{sale_id}/receipt \
  -H "Authorization: Bearer {token}"
```
