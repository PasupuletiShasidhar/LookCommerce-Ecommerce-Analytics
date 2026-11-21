/* ============================================================================
   PROJECT: E-Commerce Sales & Customer Retention Analysis
   FILE:    02_Data_Cleaning.sql
   PURPOSE: Audit raw data anomalies, convert string prices/timestamps into
            strict DECIMAL and DATETIME2 types, standardize text fields,
            and handle NULL values safely for downstream EDA and Power BI.
============================================================================ */

USE Look_Commerce_DB;
GO

/* ----------------------------------------------------------------------------
   STEP 1: DATA QUALITY AUDIT (Run before modifying data)
---------------------------------------------------------------------------- */

-- 1A. Check if any raw price/cost strings fail numeric conversion
SELECT 'products.cost' AS column_checked, COUNT(*) AS invalid_or_null_count
FROM products
WHERE TRY_CAST(cost AS DECIMAL(10, 4)) IS NULL
UNION ALL
SELECT 'products.retail_price', COUNT(*)
FROM products
WHERE TRY_CAST(retail_price AS DECIMAL(10, 4)) IS NULL
UNION ALL
SELECT 'inventory_items.cost', COUNT(*)
FROM inventory_items
WHERE TRY_CAST(cost AS DECIMAL(10, 4)) IS NULL
UNION ALL
SELECT 'inventory_items.product_retail_price', COUNT(*)
FROM inventory_items
WHERE TRY_CAST(product_retail_price AS DECIMAL(10, 4)) IS NULL
UNION ALL
SELECT 'order_items.sale_price', COUNT(*)
FROM order_items
WHERE TRY_CAST(sale_price AS DECIMAL(10, 4)) IS NULL;

-- 1B. Check missing/NULL values in key descriptive fields
SELECT 
    SUM(CASE WHEN brand IS NULL OR LTRIM(RTRIM(brand)) = '' THEN 1 ELSE 0 END) AS missing_product_brands,
    SUM(CASE WHEN category IS NULL OR LTRIM(RTRIM(category)) = '' THEN 1 ELSE 0 END) AS missing_product_categories,
    SUM(CASE WHEN name IS NULL OR LTRIM(RTRIM(name)) = '' THEN 1 ELSE 0 END) AS missing_product_names
FROM products;

-- 1C. Check distinct status & gender values for casing/whitespace issues
SELECT DISTINCT status, LEN(status) AS char_len FROM orders;
SELECT DISTINCT gender, LEN(gender) AS char_len FROM users;
GO



/* ----------------------------------------------------------------------------
   STEP 2: DATA TYPE CONVERSIONS & STANDARDIZATION
---------------------------------------------------------------------------- */

-- 2A. Convert Monetary Columns from NVARCHAR to Strict DECIMAL(10, 4)
ALTER TABLE products ALTER COLUMN cost DECIMAL(10, 4) NOT NULL;
ALTER TABLE products ALTER COLUMN retail_price DECIMAL(10, 4) NOT NULL;

ALTER TABLE inventory_items ALTER COLUMN cost DECIMAL(10, 4) NOT NULL;
ALTER TABLE inventory_items ALTER COLUMN product_retail_price DECIMAL(10, 4) NOT NULL;

ALTER TABLE order_items ALTER COLUMN sale_price DECIMAL(10, 4) NOT NULL;
GO

-- 2B. Impute Missing Descriptive Text in Products & Inventory Items
UPDATE products
SET brand = 'Unbranded'
WHERE brand IS NULL OR LTRIM(RTRIM(brand)) = '';

UPDATE products
SET name = 'Unknown Product - ID ' + CAST(id AS NVARCHAR(20))
WHERE name IS NULL OR LTRIM(RTRIM(name)) = '';

UPDATE inventory_items
SET product_brand = 'Unbranded'
WHERE product_brand IS NULL OR LTRIM(RTRIM(product_brand)) = '';

UPDATE inventory_items
SET product_name = 'Unknown Product - ID ' + CAST(product_id AS NVARCHAR(20))
WHERE product_name IS NULL OR LTRIM(RTRIM(product_name)) = '';
GO

-- 2C. Standardize Gender Labels ('F' -> 'Female', 'M' -> 'Male')
UPDATE users
SET gender = CASE 
    WHEN gender = 'F' THEN 'Female'
    WHEN gender = 'M' THEN 'Male'
    ELSE 'Unknown'
END;

UPDATE orders
SET gender = CASE 
    WHEN gender = 'F' THEN 'Female'
    WHEN gender = 'M' THEN 'Male'
    ELSE 'Unknown'
END;
GO

-- 2D. Strip ' UTC' Suffix and Convert Timestamps to DATETIME2(0)
-- Users
UPDATE users SET created_at = REPLACE(created_at, ' UTC', '') WHERE created_at LIKE '% UTC%';
ALTER TABLE users ALTER COLUMN created_at DATETIME2(0) NOT NULL;

-- Orders
UPDATE orders SET created_at   = REPLACE(created_at,   ' UTC', '') WHERE created_at   LIKE '% UTC%';
UPDATE orders SET returned_at  = REPLACE(returned_at,  ' UTC', '') WHERE returned_at  LIKE '% UTC%';
UPDATE orders SET shipped_at   = REPLACE(shipped_at,   ' UTC', '') WHERE shipped_at   LIKE '% UTC%';
UPDATE orders SET delivered_at = REPLACE(delivered_at, ' UTC', '') WHERE delivered_at LIKE '% UTC%';

ALTER TABLE orders ALTER COLUMN created_at   DATETIME2(0) NOT NULL;
ALTER TABLE orders ALTER COLUMN returned_at  DATETIME2(0) NULL;
ALTER TABLE orders ALTER COLUMN shipped_at   DATETIME2(0) NULL;
ALTER TABLE orders ALTER COLUMN delivered_at DATETIME2(0) NULL;

-- Order Items
UPDATE order_items SET created_at   = REPLACE(created_at,   ' UTC', '') WHERE created_at   LIKE '% UTC%';
UPDATE order_items SET shipped_at   = REPLACE(shipped_at,   ' UTC', '') WHERE shipped_at   LIKE '% UTC%';
UPDATE order_items SET delivered_at = REPLACE(delivered_at, ' UTC', '') WHERE delivered_at LIKE '% UTC%';
UPDATE order_items SET returned_at  = REPLACE(returned_at,  ' UTC', '') WHERE returned_at  LIKE '% UTC%';

ALTER TABLE order_items ALTER COLUMN created_at   DATETIME2(0) NOT NULL;
ALTER TABLE order_items ALTER COLUMN shipped_at   DATETIME2(0) NULL;
ALTER TABLE order_items ALTER COLUMN delivered_at DATETIME2(0) NULL;
ALTER TABLE order_items ALTER COLUMN returned_at  DATETIME2(0) NULL;

-- Inventory Items
UPDATE inventory_items SET created_at = REPLACE(created_at, ' UTC', '') WHERE created_at LIKE '% UTC%';
UPDATE inventory_items SET sold_at    = REPLACE(sold_at,    ' UTC', '') WHERE sold_at    LIKE '% UTC%';

ALTER TABLE inventory_items ALTER COLUMN created_at DATETIME2(0) NOT NULL;
ALTER TABLE inventory_items ALTER COLUMN sold_at    DATETIME2(0) NULL;

-- Events 
UPDATE events SET created_at = REPLACE(created_at, ' UTC', '') WHERE created_at LIKE '% UTC%';
ALTER TABLE events ALTER COLUMN created_at DATETIME2(0) NOT NULL;
GO


/* ----------------------------------------------------------------------------
   STEP 3: POST-CLEANING VERIFICATION & LOGICAL ANOMALY CHECK
---------------------------------------------------------------------------- */

-- 3A. Confirm zero remaining missing brands or names in products
SELECT 
    SUM(CASE WHEN brand IS NULL OR brand = '' THEN 1 ELSE 0 END) AS remaining_null_brands,
    SUM(CASE WHEN name IS NULL OR name = '' THEN 1 ELSE 0 END) AS remaining_null_names
FROM products;

-- 3B. Check date range of the dataset and verify DATETIME2 conversion
SELECT 
    MIN(created_at) AS earliest_order_date,
    MAX(created_at) AS latest_order_date,
    COUNT(*) AS total_orders
FROM orders;

-- 3C. Check for logical anomalies (Negative margins or impossible delivery timestamps)
SELECT 
    SUM(CASE WHEN oi.sale_price < p.cost THEN 1 ELSE 0 END) AS negative_margin_items,
    SUM(CASE WHEN o.delivered_at < o.created_at THEN 1 ELSE 0 END) AS delivered_before_order_count,
    SUM(CASE WHEN o.returned_at < o.delivered_at THEN 1 ELSE 0 END) AS returned_before_delivery_count
FROM order_items oi
JOIN products p ON oi.product_id = p.id
JOIN orders o ON oi.order_id = o.order_id;
GO