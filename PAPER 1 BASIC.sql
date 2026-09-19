--SQL PRACTICE QUESTION

--JOINS

--1. (Easy) List every order with the customer's full name, store name, and the full name of the staff member who handled it..

SELECT
    o.order_id,
    c.first_name + ' ' + c.last_name   AS 
    customer_name,
    s.store_name,
    st.first_name + ' ' + st.last_name AS
    staff_name
FROM sales.orders    AS o
join sales.customers AS c 
ON c.customer_id = o.customer_id
join sales.stores  
AS s  ON s.store_id    = o.store_id
join sales.staffs 
AS st ON st.staff_id   = o.staff_id
ORDER BY o.order_id;

--2. (Easy) Show each product with its brand name and category name. Include products even if they have no brand or category assigned..

SELECT p.product_id, p.product_name, 
b.brand_name, c.category_name
FROM production.products p
LEFT JOIN production.brands    
b ON b.brand_id    = p.brand_id
LEFT JOIN production.categories c ON
c.category_id = p.category_id;

--3. (Medium) Find all customers who have never placed an order. Return their name, city, and email.
--ANTI JOIN


SELECT
    (SELECT COUNT(*) FROM sales.customers)   
    AS total_customers,
    (SELECT COUNT(DISTINCT customer_id)
    FROM sales.orders)  AS
    customers_with_orders;


    --GROUP BY

--4. (Easy) Calculate total revenue per store. Revenue = quantity * list_price * (1 - discount). Sort from highest to SELECT
SELECT
    s.store_name,
    SUM(oi.quantity * oi.list_price *
    (1 - oi.discount)) AS total_revenue
FROM sales.orders    
AS o
JOIN sales.order_items AS oi
ON oi.order_id = o.order_id
JOIN sales.stores      AS s  
ON s.store_id  = o.store_id
GROUP BY s.store_id, s.store_name
ORDER BY total_revenue DESC;

--5. (Medium) For each brand, show the number of products, the average list price, and the highest list price. Only include brands with more than 5 products.
SELECT
    b.brand_name,
    COUNT(*) AS product_count,
    ROUND(AVG(p.list_price), 2) AS avg_list_price,
    MAX(p.list_price)         
    AS max_list_price
FROM production.products AS p
JOIN production.brands   AS b
ON b.brand_id = p.brand_id
GROUP BY b.brand_id, b.brand_name
HAVING COUNT(*) > 5;




--6. (Medium) Show the number of orders and total revenue per month for the year 2017, ordered chronologically.
SELECT
    YEAR(o.order_date)  AS order_year,
    MONTH(o.order_date) AS order_month,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(oi.quantity * oi.list_price * 
    (1 - oi.discount)) AS total_revenue
FROM sales.orders      AS o
JOIN sales.order_items AS oi ON oi.order_id = o.order_id
WHERE o.order_date >= '2017-01-01'
  AND o.order_date <  '2018-01-01'
GROUP BY YEAR(o.order_date), MONTH(o.order_date)
ORDER BY order_year, order_month;

--Subqueries

--7. (Medium) Find all products priced above the average list price of their own category.

--Hint: Use a correlated subquery.

SELECT p.product_name, p.list_price, c.category_name
FROM production.products   AS p
JOIN production.categories AS c ON c.category_id = p.category_id
WHERE p.list_price > (
    SELECT AVG(p2.list_price)
    FROM production.products AS p2
    WHERE p2.category_id = p.category_id
);



--8. (Medium) List the customers who have placed more orders than the average number of orders per customer.
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ',
    c.last_name) AS customer_name,
    COUNT(*) AS order_count
FROM sales.customers AS c
JOIN sales.orders    AS o 
ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING COUNT(*) > (
    SELECT AVG(cnt * 1.0)
    FROM (SELECT COUNT(*) AS cnt FROM sales.orders GROUP BY customer_id) AS t
);

--CTEs

--9. (Hard) Using a CTE, calculate each customer's total spend, then return the top 10 customers with their spend and rank. Add a second CTE that labels each customer as "High" (above the overall average spend) or "Regular".
WITH customer_spend AS (
    SELECT
 c.customer_id,
 CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
 SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spend
FROM sales.customers   AS c
JOIN sales.orders      AS o  ON o.customer_id = c.customer_id
    JOIN sales.order_items AS oi ON oi.order_id   = o.order_id
    GROUP BY c.customer_id, c.first_name, c.last_name
),
labeled AS (
 SELECT
 cs.*,
(SELECT COUNT(*) FROM customer_spend x
 WHERE x.total_spend > cs.total_spend) + 1 AS spend_rank,
 CASE WHEN cs.total_spend > (SELECT AVG(total_spend) FROM customer_spend)
THEN 'High' ELSE 'Regular' END        AS segment
FROM customer_spend AS cs
)
SELECT TOP 10 *
FROM labeled
ORDER BY spend_rank;

--10. (Hard) Using CTEs, find the best-selling product (by quantity) in each category, and show how much of that product's stock is currently available across all stores.

--Hint: Use ROW_NUMBER() or RANK() partitioned by category, then join to production.stocks
WITH product_sales AS (
    SELECT p.product_id, p.product_name, p.category_id,
           SUM(oi.quantity) AS total_qty
    FROM production.products p
    JOIN sales.order_items oi ON p.product_id = oi.product_id
    GROUP BY p.product_id, p.product_name, p.category_id
),

ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY total_qty DESC) AS rn
    FROM product_sales
)

SELECT c.category_name, r.product_name, r.total_qty,
       COALESCE(SUM(s.quantity), 0) AS stock_available
FROM ranked r
JOIN production.categories c ON r.category_id = c.category_id
LEFT JOIN production.stocks s ON r.product_id = s.product_id
WHERE r.rn = 1
GROUP BY c.category_name, r.product_name, r.total_qty;