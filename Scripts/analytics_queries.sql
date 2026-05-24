/*
===============================================================================
Analytics Queries: Gold Layer — Data Warehouse
===============================================================================
Schema    : gold
Views     : gold.fact_sales | gold.dim_customers | gold.dim_products
Purpose   : Business intelligence queries covering sales performance,
            customer behaviour, and product analytics.

Run Order : Any query can be run independently.
===============================================================================
*/


-- ===========================================================================
-- SECTION 1: SALES PERFORMANCE
-- ===========================================================================

-- 1.1 Total Revenue, Orders & Quantity Sold (Overall)
-- -------------------------------------------------------
SELECT
    COUNT(DISTINCT order_number)   AS total_orders,
    SUM(sales_amount)              AS total_revenue,
    SUM(quantity)                  AS total_units_sold,
    ROUND(AVG(sales_amount), 2)    AS avg_order_value
FROM gold.fact_sales;


-- 1.2 Revenue by Year and Month (Trend Analysis)
-- -------------------------------------------------------
SELECT
    EXTRACT(YEAR  FROM order_date)  AS order_year,
    EXTRACT(MONTH FROM order_date)  AS order_month,
    SUM(sales_amount)               AS monthly_revenue,
    COUNT(DISTINCT order_number)    AS monthly_orders,
    SUM(quantity)                   AS monthly_units
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY order_year, order_month
ORDER BY order_year, order_month;


-- 1.3 Revenue by Year (Year-over-Year Comparison)
-- -------------------------------------------------------
SELECT
    EXTRACT(YEAR FROM order_date)                        AS order_year,
    SUM(sales_amount)                                    AS yearly_revenue,
    LAG(SUM(sales_amount)) OVER (ORDER BY
        EXTRACT(YEAR FROM order_date))                   AS prev_year_revenue,
    ROUND(
        (SUM(sales_amount) - LAG(SUM(sales_amount)) OVER (ORDER BY EXTRACT(YEAR FROM order_date)))
        / NULLIF(LAG(SUM(sales_amount)) OVER (ORDER BY EXTRACT(YEAR FROM order_date)), 0) * 100
    , 2)                                                 AS yoy_growth_pct
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY order_year
ORDER BY order_year;


-- 1.4 Average Shipping Days (Fulfilment Speed)
-- -------------------------------------------------------
SELECT
    ROUND(AVG(shipping_date - order_date), 1) AS avg_shipping_days,
    MIN(shipping_date - order_date)           AS min_shipping_days,
    MAX(shipping_date - order_date)           AS max_shipping_days
FROM gold.fact_sales
WHERE order_date IS NOT NULL
  AND shipping_date IS NOT NULL;


-- ===========================================================================
-- SECTION 2: PRODUCT ANALYTICS
-- ===========================================================================

-- 2.1 Top 10 Products by Revenue
-- -------------------------------------------------------
SELECT
    p.product_name,
    p.category,
    p.subcategory,
    SUM(f.sales_amount)           AS total_revenue,
    SUM(f.quantity)               AS total_units_sold,
    ROUND(AVG(f.price), 2)        AS avg_selling_price
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_name, p.category, p.subcategory
ORDER BY total_revenue DESC
LIMIT 10;


-- 2.2 Bottom 10 Products by Revenue (Low Performers)
-- -------------------------------------------------------
SELECT
    p.product_name,
    p.category,
    SUM(f.sales_amount) AS total_revenue,
    SUM(f.quantity)     AS total_units_sold
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_name, p.category
ORDER BY total_revenue ASC
LIMIT 10;


-- 2.3 Revenue by Category
-- -------------------------------------------------------
SELECT
    p.category,
    SUM(f.sales_amount)                              AS total_revenue,
    ROUND(
        SUM(f.sales_amount) * 100.0
        / SUM(SUM(f.sales_amount)) OVER ()
    , 2)                                             AS revenue_share_pct,
    COUNT(DISTINCT f.order_number)                   AS total_orders,
    SUM(f.quantity)                                  AS total_units
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY total_revenue DESC;


-- 2.4 Revenue by Category and Subcategory
-- -------------------------------------------------------
SELECT
    p.category,
    p.subcategory,
    SUM(f.sales_amount)          AS total_revenue,
    SUM(f.quantity)              AS total_units,
    ROUND(AVG(f.price), 2)       AS avg_price
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.category, p.subcategory
ORDER BY p.category, total_revenue DESC;


-- 2.5 Revenue by Product Line
-- -------------------------------------------------------
SELECT
    p.product_line,
    SUM(f.sales_amount)          AS total_revenue,
    SUM(f.quantity)              AS total_units,
    COUNT(DISTINCT f.order_number) AS total_orders
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_line
ORDER BY total_revenue DESC;


-- 2.6 Price vs Cost Margin by Product
-- -------------------------------------------------------
SELECT
    p.product_name,
    p.category,
    p.cost,
    ROUND(AVG(f.price), 2)                              AS avg_selling_price,
    ROUND(AVG(f.price) - p.cost, 2)                     AS avg_margin,
    ROUND((AVG(f.price) - p.cost) / NULLIF(p.cost, 0) * 100, 2) AS margin_pct
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_name, p.category, p.cost
ORDER BY margin_pct DESC;


-- ===========================================================================
-- SECTION 3: CUSTOMER ANALYTICS
-- ===========================================================================

-- 3.1 Total Customers vs Buying Customers
-- -------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM gold.dim_customers)                          AS total_customers,
    COUNT(DISTINCT f.customer_key)                                     AS buying_customers,
    (SELECT COUNT(*) FROM gold.dim_customers)
        - COUNT(DISTINCT f.customer_key)                               AS non_buying_customers
FROM gold.fact_sales f;


-- 3.2 Top 10 Customers by Revenue
-- -------------------------------------------------------
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name     AS full_name,
    c.country,
    SUM(f.sales_amount)                    AS total_revenue,
    COUNT(DISTINCT f.order_number)         AS total_orders,
    SUM(f.quantity)                        AS total_units_bought,
    ROUND(AVG(f.sales_amount), 2)          AS avg_order_value
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.customer_id, full_name, c.country
ORDER BY total_revenue DESC
LIMIT 10;


-- 3.3 Revenue by Country
-- -------------------------------------------------------
SELECT
    c.country,
    SUM(f.sales_amount)                                    AS total_revenue,
    ROUND(
        SUM(f.sales_amount) * 100.0
        / SUM(SUM(f.sales_amount)) OVER ()
    , 2)                                                   AS revenue_share_pct,
    COUNT(DISTINCT f.customer_key)                         AS unique_customers,
    COUNT(DISTINCT f.order_number)                         AS total_orders
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.country
ORDER BY total_revenue DESC;


-- 3.4 Revenue by Gender
-- -------------------------------------------------------
SELECT
    c.gender,
    COUNT(DISTINCT c.customer_key)       AS total_customers,
    SUM(f.sales_amount)                  AS total_revenue,
    ROUND(AVG(f.sales_amount), 2)        AS avg_order_value
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.gender
ORDER BY total_revenue DESC;


-- 3.5 Revenue by Marital Status
-- -------------------------------------------------------
SELECT
    c.marital_status,
    COUNT(DISTINCT c.customer_key)       AS total_customers,
    SUM(f.sales_amount)                  AS total_revenue,
    ROUND(AVG(f.sales_amount), 2)        AS avg_order_value
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.marital_status
ORDER BY total_revenue DESC;


-- 3.6 Customer Age Segmentation
-- -------------------------------------------------------
SELECT
    CASE
        WHEN EXTRACT(YEAR FROM AGE(c.birthdate)) < 25 THEN 'Under 25'
        WHEN EXTRACT(YEAR FROM AGE(c.birthdate)) BETWEEN 25 AND 34 THEN '25–34'
        WHEN EXTRACT(YEAR FROM AGE(c.birthdate)) BETWEEN 35 AND 44 THEN '35–44'
        WHEN EXTRACT(YEAR FROM AGE(c.birthdate)) BETWEEN 45 AND 54 THEN '45–54'
        WHEN EXTRACT(YEAR FROM AGE(c.birthdate)) >= 55 THEN '55+'
        ELSE 'Unknown'
    END                                  AS age_group,
    COUNT(DISTINCT c.customer_key)       AS total_customers,
    SUM(f.sales_amount)                  AS total_revenue,
    ROUND(AVG(f.sales_amount), 2)        AS avg_order_value
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY age_group
ORDER BY total_revenue DESC;


-- 3.7 Customer Lifetime Value (CLV) Segments
-- -------------------------------------------------------
WITH customer_totals AS (
    SELECT
        c.customer_id,
        c.first_name || ' ' || c.last_name  AS full_name,
        SUM(f.sales_amount)                 AS lifetime_value,
        COUNT(DISTINCT f.order_number)      AS total_orders
    FROM gold.fact_sales f
    JOIN gold.dim_customers c ON f.customer_key = c.customer_key
    GROUP BY c.customer_id, full_name
)
SELECT
    CASE
        WHEN lifetime_value >= 5000 THEN 'High Value'
        WHEN lifetime_value BETWEEN 1000 AND 4999 THEN 'Mid Value'
        ELSE 'Low Value'
    END                          AS clv_segment,
    COUNT(*)                     AS customer_count,
    SUM(lifetime_value)          AS segment_revenue,
    ROUND(AVG(lifetime_value), 2) AS avg_lifetime_value
FROM customer_totals
GROUP BY clv_segment
ORDER BY segment_revenue DESC;


-- ===========================================================================
-- SECTION 4: ADVANCED / COMBINED ANALYTICS
-- ===========================================================================

-- 4.1 Running Total Revenue Over Time
-- -------------------------------------------------------
SELECT
    order_date,
    SUM(sales_amount)                                    AS daily_revenue,
    SUM(SUM(sales_amount)) OVER (ORDER BY order_date)   AS running_total_revenue
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY order_date
ORDER BY order_date;


-- 4.2 Product Revenue Rank Within Each Category
-- -------------------------------------------------------
SELECT
    p.category,
    p.product_name,
    SUM(f.sales_amount)                                        AS total_revenue,
    RANK() OVER (PARTITION BY p.category ORDER BY SUM(f.sales_amount) DESC) AS rank_in_category
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.category, p.product_name
ORDER BY p.category, rank_in_category;


-- 4.3 Month-over-Month Revenue Change
-- -------------------------------------------------------
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', order_date)   AS month,
        SUM(sales_amount)                 AS revenue
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY month
)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month)   AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month))
        / NULLIF(LAG(revenue) OVER (ORDER BY month), 0) * 100
    , 2)                                 AS mom_growth_pct
FROM monthly
ORDER BY month;


-- 4.4 Best Selling Product Per Country
-- -------------------------------------------------------
WITH ranked AS (
    SELECT
        c.country,
        p.product_name,
        SUM(f.sales_amount)                                          AS total_revenue,
        RANK() OVER (PARTITION BY c.country ORDER BY SUM(f.sales_amount) DESC) AS rnk
    FROM gold.fact_sales f
    JOIN gold.dim_customers c ON f.customer_key = c.customer_key
    JOIN gold.dim_products  p ON f.product_key  = p.product_key
    GROUP BY c.country, p.product_name
)
SELECT country, product_name, total_revenue
FROM ranked
WHERE rnk = 1
ORDER BY total_revenue DESC;


-- 4.5 Customer Retention — Repeat vs One-Time Buyers
-- -------------------------------------------------------
WITH order_counts AS (
    SELECT
        customer_key,
        COUNT(DISTINCT order_number) AS total_orders
    FROM gold.fact_sales
    GROUP BY customer_key
)
SELECT
    CASE
        WHEN total_orders = 1 THEN 'One-Time Buyer'
        WHEN total_orders BETWEEN 2 AND 5 THEN 'Repeat Buyer'
        ELSE 'Loyal Buyer'
    END                    AS buyer_segment,
    COUNT(*)               AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers
FROM order_counts
GROUP BY buyer_segment
ORDER BY customer_count DESC;


-- 4.6 Full Customer 360 View
-- -------------------------------------------------------
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name      AS full_name,
    c.country,
    c.gender,
    c.marital_status,
    EXTRACT(YEAR FROM AGE(c.birthdate))      AS age,
    COUNT(DISTINCT f.order_number)           AS total_orders,
    SUM(f.sales_amount)                      AS total_revenue,
    MIN(f.order_date)                        AS first_order_date,
    MAX(f.order_date)                        AS last_order_date,
    NOW()::DATE - MAX(f.order_date)          AS days_since_last_order
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY
    c.customer_id, full_name, c.country,
    c.gender, c.marital_status, c.birthdate
ORDER BY total_revenue DESC;
