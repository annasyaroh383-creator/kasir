# Database Schema Design for Smart Cashier Application

## Overview

The database is designed for a modern POS system with inventory management, customer membership, sales tracking, payment processing, and AI-powered product recommendations using market basket analysis.

## Core Tables

### 1. users

Manages system users (admins and cashiers)

- id (BIGINT, PRIMARY KEY, AUTO_INCREMENT)
- name (VARCHAR(255))
- email (VARCHAR(255), UNIQUE)
- password (VARCHAR(255), hashed)
- role (ENUM: 'admin', 'cashier')
- is_active (BOOLEAN, default TRUE)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)

### 2. customers

Customer information and membership data

- id (BIGINT, PRIMARY KEY, AUTO_INCREMENT)
- name (VARCHAR(255))
- email (VARCHAR(255), UNIQUE, nullable)
- phone (VARCHAR(20), nullable)
- membership_id (VARCHAR(50), UNIQUE, nullable)
- points (DECIMAL(10,2), default 0)
- total_spent (DECIMAL(15,2), default 0)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)

### 3. categories

Product categories for organization

- id (BIGINT, PRIMARY KEY, AUTO_INCREMENT)
- name (VARCHAR(255), UNIQUE)
- description (TEXT, nullable)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)

### 4. products

Product catalog with inventory tracking

- id (BIGINT, PRIMARY KEY, AUTO_INCREMENT)
- name (VARCHAR(255))
- barcode (VARCHAR(100), UNIQUE)
- category_id (BIGINT, FOREIGN KEY -> categories.id)
- price (DECIMAL(15,2))
- cost_price (DECIMAL(15,2))
- stock_quantity (INT)
- min_stock_level (INT, default 0)
- description (TEXT, nullable)
- image_url (VARCHAR(500), nullable)
- is_active (BOOLEAN, default TRUE)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)

### 5. inventory_movements

Tracks all stock changes

- id (BIGINT, PRIMARY KEY, AUTO_INCREMENT)
- product_id (BIGINT, FOREIGN KEY -> products.id)
- type (ENUM: 'in', 'out', 'adjustment', 'sale', 'return')
- quantity (INT)
- previous_stock (INT)
- new_stock (INT)
- reason (TEXT, nullable)
- reference_id (BIGINT, nullable) // sale_id or adjustment_id
- user_id (BIGINT, FOREIGN KEY -> users.id)
- created_at (TIMESTAMP)

### 6. sales

Transaction records

- id (BIGINT, PRIMARY KEY, AUTO_INCREMENT)
- customer_id (BIGINT, FOREIGN KEY -> customers.id, nullable)
- user_id (BIGINT, FOREIGN KEY -> users.id)
- total_amount (DECIMAL(15,2))
- discount_amount (DECIMAL(10,2), default 0)
- tax_amount (DECIMAL(10,2), default 0)
- final_amount (DECIMAL(15,2))
- status (ENUM: 'pending', 'completed', 'cancelled', 'refunded')
- payment_status (ENUM: 'unpaid', 'partial', 'paid')
- notes (TEXT, nullable)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)

### 7. sale_items

Individual items in each sale

- id (BIGINT, PRIMARY KEY, AUTO_INCREMENT)
- sale_id (BIGINT, FOREIGN KEY -> sales.id)
- product_id (BIGINT, FOREIGN KEY -> products.id)
- quantity (INT)
- unit_price (DECIMAL(15,2))
- discount (DECIMAL(10,2), default 0)
- subtotal (DECIMAL(15,2))
- created_at (TIMESTAMP)

### 8. payments

Payment records for sales

- id (BIGINT, PRIMARY KEY, AUTO_INCREMENT)
- sale_id (BIGINT, FOREIGN KEY -> sales.id)
- method (ENUM: 'cash', 'qris', 'e_money', 'card')
- amount (DECIMAL(15,2))
- reference_number (VARCHAR(255), nullable) // QRIS ref or card number
- status (ENUM: 'pending', 'completed', 'failed', 'refunded')
- payment_data (JSON, nullable) // store additional payment info
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)

### 9. purchase_history

Detailed purchase history for AI analysis

- id (BIGINT, PRIMARY KEY, AUTO_INCREMENT)
- customer_id (BIGINT, FOREIGN KEY -> customers.id)
- product_id (BIGINT, FOREIGN KEY -> products.id)
- sale_id (BIGINT, FOREIGN KEY -> sales.id)
- quantity (INT)
- unit_price (DECIMAL(15,2))
- purchase_date (DATE)
- created_at (TIMESTAMP)

### 10. product_recommendations

AI-generated recommendations

- id (BIGINT, PRIMARY KEY, AUTO_INCREMENT)
- customer_id (BIGINT, FOREIGN KEY -> customers.id)
- recommended_product_id (BIGINT, FOREIGN KEY -> products.id)
- base_product_id (BIGINT, FOREIGN KEY -> products.id, nullable)
- confidence_score (DECIMAL(5,4)) // 0.0000 to 1.0000
- support_count (INT)
- recommendation_type (ENUM: 'frequent_itemset', 'personalized', 'trending')
- is_active (BOOLEAN, default TRUE)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)

## Relationships Summary

- users: 1:N sales, 1:N inventory_movements
- customers: 1:N sales, 1:N purchase_history, 1:N product_recommendations
- categories: 1:N products
- products: N:1 categories, 1:N inventory_movements, 1:N sale_items, 1:N purchase_history
- sales: N:1 users, N:1 customers, 1:N sale_items, 1:N payments
- sale_items: N:1 sales, N:1 products
- payments: N:1 sales
- inventory_movements: N:1 products, N:1 users
- purchase_history: N:1 customers, N:1 products, N:1 sales
- product_recommendations: N:1 customers, N:1 products (recommended), N:1 products (base)

## Indexes for Performance

- users: email, role
- customers: email, phone, membership_id
- products: barcode, category_id, is_active
- sales: customer_id, user_id, status, payment_status, created_at
- sale_items: sale_id, product_id
- payments: sale_id, method, status
- purchase_history: customer_id, product_id, purchase_date
- product_recommendations: customer_id, recommended_product_id, confidence_score

## Production Considerations

- Use InnoDB storage engine
- Enable foreign key constraints
- Implement soft deletes for critical tables (users, customers, products, sales)
- Add database triggers for automatic stock updates
- Implement audit logging for financial transactions
- Use database transactions for sales and inventory operations
- Set up database backups and replication
- Optimize for read-heavy operations (caching strategies)
