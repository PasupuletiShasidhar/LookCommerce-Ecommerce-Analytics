/* ============================================================================
   PROJECT: E-Commerce Sales & Customer Retention Analysis
   FILE:    04_Business_Analysis_and_Views.sql
   PURPOSE: Build RFM customer segmentation and create clean dimensional/fact
            SQL Views for direct consumption in Power BI Desktop.
============================================================================ */

USE Look_Commerce_DB;

/* ----------------------------------------------------------------------------
   1. RFM CUSTOMER SEGMENTATION SUMMARY (Completed Orders Only)
---------------------------------------------------------------------------- */
WITH dataset_anchor AS (
    SELECT MAX(created_at) AS max_date FROM orders
),
customer_rfm_raw AS (
    SELECT 
        oi.user_id,
        DATEDIFF(DAY, MAX(oi.created_at), (SELECT max_date FROM dataset_anchor)) AS recency_days,
        COUNT(DISTINCT oi.order_id) AS frequency,
        ROUND(SUM(oi.sale_price), 2) AS monetary
    FROM order_items oi
    WHERE oi.status = 'Complete'
    GROUP BY oi.user_id
),
rfm_scores AS (
    SELECT 
        user_id,
        recency_days,
        frequency,
        monetary,
        NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(4) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(4) OVER (ORDER BY monetary ASC) AS m_score
    FROM customer_rfm_raw
),
rfm_segmented AS (
    SELECT 
        *,
        CASE 
            WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Champions'
            WHEN f_score >= 3 AND m_score >= 2 THEN 'Loyal Customers'
            WHEN r_score >= 3 AND f_score <= 2 THEN 'Recent / Potential Loyalists'
            WHEN r_score = 2 THEN 'At Risk'
            ELSE 'Hibernating / Lost'
        END AS rfm_segment
    FROM rfm_scores
)
SELECT 
    rfm_segment,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers,
    ROUND(AVG(recency_days), 0) AS avg_recency_days,
    ROUND(AVG(CAST(frequency AS FLOAT)), 2) AS avg_orders,
    ROUND(AVG(monetary), 2) AS avg_monetary_ltv,
    ROUND(SUM(monetary), 2) AS total_segment_revenue
FROM rfm_segmented
GROUP BY rfm_segment
ORDER BY total_segment_revenue DESC;



/* ----------------------------------------------------------------------------
   2. PRODUCTION VIEWS FOR POWER BI STAR SCHEMA
---------------------------------------------------------------------------- */

-- 2A. Fact Table View: Order Line Items with Profit & Fulfillment Lead Times
CREATE OR ALTER VIEW vw_fact_sales AS
SELECT 
    oi.id AS order_item_id,
    oi.order_id,
    oi.user_id,
    oi.product_id,
    p.distribution_center_id,
    oi.status AS item_status,
    CAST(oi.created_at AS DATE) AS order_date,
    oi.created_at,
    oi.shipped_at,
    oi.delivered_at,
    oi.returned_at,
    DATEDIFF(HOUR, oi.created_at, oi.shipped_at) AS hours_to_ship,
    DATEDIFF(DAY, oi.created_at, oi.delivered_at) AS days_to_deliver,
    oi.sale_price,
    p.cost AS product_cost,
    (oi.sale_price - p.cost) AS gross_profit
FROM order_items oi
JOIN products p ON oi.product_id = p.id;
GO

-- 2B. Dimension View: Customers
CREATE OR ALTER VIEW vw_dim_customers AS
SELECT 
    id AS user_id,
    first_name + ' ' + last_name AS full_name,
    age,
    CASE 
        WHEN age < 25 THEN 'Under 25'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 49 THEN '35-49'
        ELSE '50+'
    END AS age_group,
    gender,
    country,
    state,
    city,
    traffic_source,
    CAST(created_at AS DATE) AS signup_date
FROM users;
GO

-- 2C. Dimension View: Products & Distribution Centers
CREATE OR ALTER VIEW vw_dim_products AS
SELECT 
    p.id AS product_id,
    p.name AS product_name,
    p.brand,
    p.category,
    p.department,
    p.sku,
    p.cost,
    p.retail_price,
    dc.name AS distribution_center_name
FROM products p
LEFT JOIN distribution_centers dc ON p.distribution_center_id = dc.id;
GO

-- 2D. Analytical View: Customer RFM Segments
CREATE OR ALTER VIEW vw_rfm_segments AS
WITH dataset_anchor AS (
    SELECT MAX(created_at) AS max_date FROM orders
),
customer_rfm_raw AS (
    SELECT 
        oi.user_id,
        DATEDIFF(DAY, MAX(oi.created_at), (SELECT max_date FROM dataset_anchor)) AS recency_days,
        COUNT(DISTINCT oi.order_id) AS frequency,
        ROUND(SUM(oi.sale_price), 2) AS monetary
    FROM order_items oi
    WHERE oi.status = 'Complete'
    GROUP BY oi.user_id
),
rfm_scores AS (
    SELECT 
        user_id,
        recency_days,
        frequency,
        monetary,
        NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(4) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(4) OVER (ORDER BY monetary ASC) AS m_score
    FROM customer_rfm_raw
)
SELECT 
    user_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CASE 
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Champions'
        WHEN f_score >= 3 AND m_score >= 2 THEN 'Loyal Customers'
        WHEN r_score >= 3 AND f_score <= 2 THEN 'Recent / Potential Loyalists'
        WHEN r_score = 2 THEN 'At Risk'
        ELSE 'Hibernating / Lost'
    END AS rfm_segment
FROM rfm_scores;
