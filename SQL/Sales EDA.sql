-- CREATE SCHEMA PLAY_GROUND;
USE PLAY_GROUND;

SELECT * 
FROM retail_sales
LIMIT 5;

-- What is the total revenue, total number of transactions, and average transaction value?-- 
SELECT 
	COUNT(*) AS total_transactions,
    FORMAT(SUM(revenue), 2) AS total_revenue,
    FORMAT(AVG(revenue), 2) AS average_transaction_volume
    FROM retail_sales;
    


-- Which 10 products generated the highest revenue and are the 10 best selling product?-- 
SELECT 
    product_name, 
    FORMAT(SUM(revenue), 2) AS product_revenue,
    SUM(quantity) AS product_volume
FROM retail_sales
GROUP BY product_name
ORDER BY SUM(revenue) DESC
LIMIT 10;

-- Which 10 product category generated the highest revenue and is the best selling category?-- 
SELECT 
    product_category, 
    FORMAT(SUM(revenue), 2) AS category_revenue,
    SUM(quantity) AS category_volume
FROM retail_sales
GROUP BY product_category
ORDER BY SUM(revenue) DESC
LIMIT 10;

-- How does total revenue and transaction volume vary across different years?--
SELECT year,
	FORMAT(SUM(revenue), 2) AS yearly_revenue,
    COUNT(revenue) AS yearly_transaction
FROM retail_sales
GROUP BY year
ORDER BY SUM(revenue) DESC;