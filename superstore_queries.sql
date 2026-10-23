USE SUPERSTORE_DB;


-- EARLIEST AND LATEST ORDER DATES
SELECT 
MIN(order_date) AS Earliest_order, 
MAX(order_date) AS Latest_order
FROM superstore;


-- UNIQUE ORDERS, CUSTOMERS, PRODUCTS AND TOTAL SALES
SELECT 
COUNT(DISTINCT order_id) AS Unique_orders,
COUNT(DISTINCT customer_id) AS Unique_customers,
COUNT(DISTINCT product_id) AS Unique_products,
SUM(sales) AS Total_sales
FROM superstore;


-- AVERAGE SALES PER ORDER
WITH Ordertotals AS(
SELECT 
order_id,
SUM(sales) AS total_order_sales
FROM superstore
GROUP BY order_id
)
SELECT 
AVG(total_order_sales) AS avg_sales_per_order
FROM Ordertotals;


-- TOP CATEGORY & SUB_CATEGORY BY SALES
SELECT category, ROUND(SUM(sales),2) AS total_sales
FROM superstore
GROUP BY category
ORDER BY total_sales DESC;

SELECT category, sub_category, ROUND(SUM(sales),2) AS total_sales
FROM superstore
GROUP BY category, sub_category
ORDER BY total_sales DESC;


-- REGION & STATE WITH MOST AND LEAST SALES
SELECT region, ROUND(SUM(sales),2) AS total_sales
FROM superstore
GROUP BY region
ORDER BY  total_sales DESC;

SELECT state,ROUND(SUM(sales),2) AS total_sales
FROM superstore
GROUP BY state
ORDER BY  total_sales ASC
LIMIT 5;


-- TOTAL SALES PER YEAR & MONTH (STRONGEST MONTH PER YEAR)
WITH monthly AS (
  SELECT YEAR(order_date) AS order_year,
         MONTH(order_date) AS order_month,
         SUM(sales) AS total_sales
  FROM superstore
  GROUP BY YEAR(order_date), MONTH(order_date)
),
ranked AS (
  SELECT *, RANK() OVER (PARTITION BY order_year ORDER BY total_sales DESC) AS rnk
  FROM monthly
)
SELECT order_year, order_month, ROUND(total_sales,2) AS total_sales
FROM ranked
WHERE rnk = 1
ORDER BY order_year;


-- TOP 10 CUSTOMERS AND THEIR SHARE OF TOTAL SALES
WITH top10 AS (
  SELECT customer_id, customer_name, SUM(sales) AS customer_sales
  FROM superstore
  GROUP BY customer_id, customer_name
  ORDER BY customer_sales DESC
  LIMIT 10
)
SELECT ROUND(SUM(customer_sales),2) AS top10_sales,
       ROUND(SUM(customer_sales) / (SELECT SUM(sales) FROM superstore) * 100, 2) AS top10_pct
FROM top10;


-- YEAR ON YEAR SALES GROWTH FOR EACH CATEGORY
WITH YearlyCategorySales AS (
    SELECT
        category,
        YEAR(order_date) AS order_year,
        SUM(sales) AS current_year_sales
    FROM superstore
    GROUP BY category, YEAR(order_date)
),
YoYCalculation AS (
    SELECT
        category,
        order_year,
        current_year_sales,
        LAG(order_year, 1) OVER (
            PARTITION BY category
            ORDER BY order_year ASC
        ) AS previous_year,
        LAG(current_year_sales, 1) OVER (
            PARTITION BY category
            ORDER BY order_year ASC
        ) AS previous_year_sales
    FROM YearlyCategorySales
)
SELECT
    category,
    order_year,
    ROUND(current_year_sales, 2) AS current_year_sales,
    ROUND(previous_year_sales, 2) AS previous_year_sales,
    ROUND(
        ((current_year_sales - previous_year_sales) / NULLIF(previous_year_sales, 0)) * 100,
        2
    ) AS yoy_growth_pct
FROM YoYCalculation
WHERE previous_year IS NULL
   OR previous_year = order_year - 1
ORDER BY category, order_year ASC;


-- TOP 3 BEST SELLING PRODUCTS IN EACH REGION
WITH ProductRegionSales AS (
    SELECT
        region,
        product_id,
        MAX(product_name) AS product_name,
        SUM(sales) AS total_sales,
        DENSE_RANK() OVER (
            PARTITION BY region
            ORDER BY SUM(sales) DESC
        ) AS product_rank
    FROM superstore
    GROUP BY region, product_id
)
SELECT
    region,
    product_rank,
    product_id,
    product_name,
    ROUND(total_sales, 2) AS total_sales
FROM ProductRegionSales
WHERE product_rank <= 3
ORDER BY region, product_rank ASC;


-- CUSTOMERS ORDERING IN ONLY ONE YEAR VS EVERY YEAR
WITH CustomerYears AS (
  SELECT customer_id,
         COUNT(DISTINCT YEAR(order_date)) AS years_active
  FROM superstore
  GROUP BY customer_id
),
TotalYears AS (
  SELECT COUNT(DISTINCT YEAR(order_date)) AS total_years
  FROM superstore
),
Labeled AS (
  SELECT c.customer_id,
         CASE
           WHEN c.years_active = 1 THEN 'Only one year'
           WHEN c.years_active = t.total_years THEN 'Every year'
           ELSE 'Some years'
         END AS customer_type
  FROM CustomerYears c
  CROSS JOIN TotalYears t
)
SELECT customer_type,
       COUNT(*) AS customers,
       ROUND(COUNT(*) * 100 / (SELECT COUNT(*) FROM Labeled), 2) AS pct_of_customers
FROM Labeled
GROUP BY customer_type
ORDER BY customers DESC;