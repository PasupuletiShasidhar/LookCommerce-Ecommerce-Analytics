/* ============================================================================
   PROJECT: E-Commerce Sales & Customer Retention Analysis
   FILE:    03_Exploratory_Data_Analysis.sql
   PURPOSE: Explore core business KPIs, order status distributions, product
            department performance, customer demographics, and traffic sources.
============================================================================ */

USE Look_Commerce_DB;


/* ----------------------------------------------------------------------------
   1. EXECUTIVE KPI BASELINE (All-Time Totals & Completed-Order Net Revenue)
---------------------------------------------------------------------------- */
SELECT 
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.user_id) AS ordering_customers,
    COUNT(oi.id) AS total_items_ordered,
    ROUND(SUM(oi.sale_price), 2) AS gross_order_value,
    ROUND(SUM(CASE WHEN oi.status = 'Complete' THEN oi.sale_price ELSE 0 END), 2) AS net_completed_revenue,
    ROUND(SUM(CASE WHEN oi.status = 'Complete' THEN oi.sale_price - p.cost ELSE 0 END), 2) AS net_gross_profit,
    ROUND(
        SUM(CASE WHEN oi.status = 'Complete' THEN oi.sale_price - p.cost ELSE 0 END) * 100.0 /
        NULLIF(SUM(CASE WHEN oi.status = 'Complete' THEN oi.sale_price ELSE 0 END), 0), 
    2) AS net_profit_margin_pct
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.id;

/* ----------------------------------------------------------------------------
   2. ORDER STATUS & FULFILLMENT FUNNEL BREAKDOWN
---------------------------------------------------------------------------- */
SELECT 
    status,
    COUNT(*) AS item_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_items,
    ROUND(SUM(sale_price), 2) AS total_value
FROM order_items
GROUP BY status
ORDER BY item_count DESC;

/* ----------------------------------------------------------------------------
   3. DEPARTMENT & TOP 10 CATEGORY PERFORMANCE (Completed Orders Only)
---------------------------------------------------------------------------- */
SELECT 
    p.department,
    p.category,
    COUNT(oi.id) AS units_sold,
    ROUND(SUM(oi.sale_price), 2) AS completed_revenue,
    ROUND(SUM(oi.sale_price - p.cost), 2) AS gross_profit,
    ROUND(AVG(oi.sale_price), 2) AS avg_item_price
FROM order_items oi
JOIN products p ON oi.product_id = p.id
WHERE oi.status = 'Complete'
GROUP BY p.department, p.category
ORDER BY completed_revenue DESC;

/* ----------------------------------------------------------------------------
   4. CUSTOMER ACQUISITION CHANNEL & TOP 10 COUNTRIES
---------------------------------------------------------------------------- */
-- 4A. Traffic Source Distribution & Conversion to Buyer
SELECT 
    u.traffic_source,
    COUNT(DISTINCT u.id) AS registered_users,
    COUNT(DISTINCT o.user_id) AS active_buyers,
    ROUND(COUNT(DISTINCT o.user_id) * 100.0 / COUNT(DISTINCT u.id), 2) AS buyer_conversion_pct
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.traffic_source
ORDER BY registered_users DESC;

-- 4B. Top 10 Countries by Registered Users & Completed Revenue
SELECT TOP 10
    u.country,
    COUNT(DISTINCT u.id) AS registered_users,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(CASE WHEN oi.status = 'Complete' THEN oi.sale_price ELSE 0 END), 2) AS completed_revenue
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY u.country
ORDER BY completed_revenue DESC;



/* ----------------------------------------------------------------------------
   5. MONTHLY REVENUE, ORDER VOLUME & GROWTH TREND (Completed Orders)
---------------------------------------------------------------------------- */
WITH monthly_sales AS (
    SELECT 
        FORMAT(oi.created_at, 'yyyy-MM') AS order_month,
        COUNT(DISTINCT oi.order_id) AS completed_orders,
        COUNT(oi.id) AS units_sold,
        ROUND(SUM(oi.sale_price), 2) AS monthly_revenue,
        ROUND(SUM(oi.sale_price - p.cost), 2) AS monthly_profit
    FROM order_items oi
    JOIN products p ON oi.product_id = p.id
    WHERE oi.status = 'Complete'
    GROUP BY FORMAT(oi.created_at, 'yyyy-MM')
)
SELECT 
    order_month,
    completed_orders,
    units_sold,
    monthly_revenue,
    monthly_profit,
    ROUND(
        (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY order_month)) * 100.0 /
        NULLIF(LAG(monthly_revenue) OVER (ORDER BY order_month), 0),
    2) AS mom_revenue_growth_pct
FROM monthly_sales
ORDER BY order_month;

/* ----------------------------------------------------------------------------
   6. CUSTOMER ORDER FREQUENCY & REPEAT BUYER DISTRIBUTION
---------------------------------------------------------------------------- */
WITH customer_orders AS (
    SELECT 
        user_id,
        COUNT(DISTINCT order_id) AS order_count,
        ROUND(SUM(sale_price), 2) AS total_spent
    FROM order_items
    WHERE status = 'Complete'
    GROUP BY user_id
)
SELECT 
    CASE 
        WHEN order_count = 1 THEN '1 Order (One-Time)'
        WHEN order_count = 2 THEN '2 Orders (Repeat)'
        WHEN order_count >= 3 THEN '3+ Orders (Loyal)'
    END AS customer_segment,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_buyers,
    ROUND(AVG(total_spent), 2) AS avg_lifetime_value
FROM customer_orders
GROUP BY 
    CASE 
        WHEN order_count = 1 THEN '1 Order (One-Time)'
        WHEN order_count = 2 THEN '2 Orders (Repeat)'
        WHEN order_count >= 3 THEN '3+ Orders (Loyal)'
    END
ORDER BY customer_count DESC;

/* ----------------------------------------------------------------------------
   7. CATEGORY RETURN & CANCELLATION RATE AUDIT (Leakage Hotspots)
---------------------------------------------------------------------------- */
SELECT TOP 10
    p.department,
    p.category,
    COUNT(oi.id) AS total_items,
    SUM(CASE WHEN oi.status = 'Returned' THEN 1 ELSE 0 END) AS returned_items,
    ROUND(SUM(CASE WHEN oi.status = 'Returned' THEN 1 ELSE 0 END) * 100.0 / COUNT(oi.id), 2) AS return_rate_pct,
    ROUND(SUM(CASE WHEN oi.status = 'Returned' THEN oi.sale_price ELSE 0 END), 2) AS lost_return_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.id
GROUP BY p.department, p.category
HAVING COUNT(oi.id) >= 500
ORDER BY return_rate_pct DESC;
