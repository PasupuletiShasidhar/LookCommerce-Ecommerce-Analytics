CREATE DATABASE Look_Commerce_DB



/* ============================================================================
   PROJECT: E-Commerce Sales & Customer Retention Analysis
   FILE:    01_Database_Setup.sql
   PURPOSE: Enforce Foreign Key relationships across Look_Commerce_DB and 
            verify raw row counts across all 7 imported tables.
============================================================================ */

USE Look_Commerce_DB;
GO

-- 1. Enforce Foreign Key Relationships
ALTER TABLE products ADD CONSTRAINT FK_products_distribution_centers
FOREIGN KEY (distribution_center_id) REFERENCES distribution_centers(id);

ALTER TABLE orders ADD CONSTRAINT FK_orders_users
FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE order_items ADD CONSTRAINT FK_order_items_orders
FOREIGN KEY (order_id) REFERENCES orders(order_id);

ALTER TABLE order_items ADD CONSTRAINT FK_order_items_users
FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE order_items ADD CONSTRAINT FK_order_items_products
FOREIGN KEY (product_id) REFERENCES products(id);

ALTER TABLE order_items ADD CONSTRAINT FK_order_items_inventory
FOREIGN KEY (inventory_item_id) REFERENCES inventory_items(id);

ALTER TABLE inventory_items ADD CONSTRAINT FK_inventory_products
FOREIGN KEY (product_id) REFERENCES products(id);
GO

-- 2. Verify Row Counts Across All 7 Tables
SELECT 'distribution_centers' AS table_name, COUNT(*) AS row_count FROM distribution_centers
UNION ALL
SELECT 'users', COUNT(*) FROM users
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'inventory_items', COUNT(*) FROM inventory_items
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'events', COUNT(*) FROM events
ORDER BY row_count DESC;
GO