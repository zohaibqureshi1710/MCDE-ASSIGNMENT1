--Assignment Tasks
--Task 1 — Build the Sales Detail Dataset (6 marks)
--Management needs a detailed sales dataset for analysis. Return one row per order item containing:
--order_id and order_date
--customer full name
--store name
--staff full name
--product name
--category name
--brand name
--quantity, list_price, discount
--calculated net_line_revenue
select o.order_id,
o.order_date, 
concat(c.first_name, ' ', c.last_name) as
customer_name,
s.store_name,
concat(st.first_name, ' ', st.last_name) as 
staff_name,p.product_name,
cat.category_name,
b.brand_name,
oi.quantity,
oi.list_price,
oi.discount,
oi.quantity * oi.list_price * (1 - oi.discount) as
net_line_revenue from sales.orders o
join sales.order_items oi on o.order_id = oi.order_id
join sales.customers c on o.customer_id = c.customer_id
join sales.stores s on o.store_id = s.store_id
join sales.staffs st on o.staff_id = st.staff_id
join production.products p on oi.product_id = p.product_id
join production.categories cat on p.category_id = cat.category_id
join production.brands b on p.brand_id = b.brand_id
where o.order_status = 4
order by o.order_date desc;



--Task 2 — Store Performance Summary (5 marks)
--Create a store-level performance report for completed orders showing:
--* store name
--* number of distinct orders
--* total units sold
--* total net revenue
--* average order value
--Return one row per store and order the stores from highest to lowest total net revenue.

select s.store_name,
count(distinct o.order_id) as total_orders,
sum(oi.quantity) as total_units_sold,
sum(oi.quantity * oi.list_price * (1 - oi.discount)) as 
total_net_revenue,
sum(oi.quantity * oi.list_price * (1 - oi.discount)) / 
count(distinct o.order_id) as avg_order_value
from sales.orders o
join sales.order_items oi on 
o.order_id = oi.order_id
join sales.stores s on 
o.store_id = s.store_id
where o.order_status = 4
group by s.store_name
order by total_net_revenue desc


--Task 3 — High-Value Customers (5 marks)
--Management wants to identify high-value customers. Return customers whose 
--total completed-order spending is greater than the average total spending of customers who have completed orders.
--Show customer_id, customer name, completed order count,
--and total spending. Order the result by total spending descending.


with customer_totals as (
    select o.customer_id,
    concat(c.first_name, ' ', c.last_name) as customer_name,
    count(distinct o.order_id) as order_count,
    sum(oi.quantity * oi.list_price *
    (1 - oi.discount)) as total_spending
    from sales.orders o
    join sales.order_items oi on
    o.order_id = oi.order_id
    join sales.customers c on 
    o.customer_id = c.customer_id
    where o.order_status = 4
    group by o.customer_id,
    c.first_name, c.last_name
)
select customer_id,
customer_name,
order_count,
total_spending
from customer_totals
where total_spending > (select avg(total_spending) from customer_totals)
order by total_spending desc

--Task 4 — Inventory Risk Report (5 marks)
--Operations wants to identify inventory risk. Return products where the stock
--quantity is below 5 in at least one store.
--Show product name, store name, current quantity, category name, and brand name. 
--Products with zero stock should appear first, followed by the lowest remaining quantities.

select p.product_name,
s.store_name,
st.quantity,
cat.category_name,
b.brand_name
from production.stocks st
join production.products p on
st.product_id = p.product_id
join sales.stores s on 
st.store_id = s.store_id
join production.categories cat on
p.category_id = cat.category_id
join production.brands b on 
p.brand_id = b.brand_id
where st.quantity < 5
order by st.quantity asc

--Task 5 — Top Products Within Each Category (6 marks)
--For each product category, identify the top 3 products by total net revenue from completed orders.
--Return category name, product name, total units sold, total net revenue, and the product's position within its category. 
--Tied products must receive the same position and the next position should not contain gaps.

with product_revenue as (
    select cat.category_name,
    p.product_name,
    sum(oi.quantity) as total_units_sold,
    sum(oi.quantity * oi.
    list_price * (1 - oi.discount)) as total_net_revenue
    from sales.orders o
    join sales.order_items oi on 
    o.order_id = oi.order_id
    join production.products p on 
    oi.product_id = p.product_id
    join production.categories cat on
    p.category_id = cat.category_id
    where o.order_status = 4
    group by cat.category_name, p.product_name
),
ranked as (
    select *,
    dense_rank() over (partition by category_name order by total_net_revenue desc) as position
    from product_revenue
)
select category_name, product_name, total_units_sold, total_net_revenue, position
from ranked
where position <= 3
order by category_name, position



--Task 6 — Monthly Sales Trend (6 marks)
--Create a monthly sales trend for completed orders.
--For each calendar month return:
--* year
--* month
--* total net revenue
--* previous month's total net revenue
--* revenue change from the previous month
--The first month may have NULL for the previous-month comparison. Sort chronologically

with m as(select year(order_date)yr,month(order_date)mon,
sum(oi.quantity*oi.list_price*(1-oi.discount))rev 
from sales.orders o join sales.order_items oi on
o.order_id=oi.order_id where order_status=4 group by year(order_date),month(order_date))
select yr,mon,rev,lag(rev)over(order by yr,mon)prev_rev,rev-lag(rev)
over(order by yr,mon)change from m order by yr,mon
.
--Task 7 — Reusable Reporting View (4 marks)
--Create a view named sales.vw_customer_sales_summary that returns one row per customer and includes:

--* customer_id
--* customer full name
--* total number of completed orders
--* total units purchased
--* total net revenue
--* most recent completed order date
--Customers with no completed orders must still be represented where possible, with appropriate zero/NULL values.


with pr as
(
select 
cat.category_name cn,
p.product_name pn,
sum(oi.quantity)units,
sum(oi.quantity*oi.
list_price*(1-oi.discount))
rev from sales.orders o join sales.
order_items oi on
o.order_id=oi.order_id join 
production.products p on oi.
product_id=p.product_id join production.categories
cat on p.category_id=cat.category_id where order_status=4 group by cat.
category_name,p.product_name),
r as(select *,dense_rank()over(partition by cn order by rev desc)pos from pr)
select cn,pn,units,rev,pos from r where pos<=3 order by cn,pos


--Task 8 — Safe Data Modification (4 marks)
--A customer with customer_id = 1 has requested that their phone number be changed to '(999) 555-0101'.
--Write SQL that performs this update inside an explicit transaction. Include a validation query after the UPDATE
--and show how the change can be rolled back during testing so the assessment database is not permanently changed.
-- rollback tran   -- use this line during testing to undo
-- commit tran     -- use this line only when actually ready to save
BEGIN TRANSACTION;
UPDATE sales.customers
SET phone = '+92-309-2340984'
WHERE customer_id = 1;
SELECT customer_id, phone
FROM sales.customers
WHERE customer_id = 1;
ROLLBACK TRANSACTION; -- use during testing
-- COMMIT TRANSACTION; -- use when ready to save




--Task 9 — Store Sales Procedure (6 marks)
--Create a stored procedure named sales.usp_store_sales_report with these input parameters:
--* @store_id
--* @start_date
--* @end_date
--The procedure should return completed-order sales for the requested store and date range, grouped by product. 
--Return product name, total units sold, and total net revenue, ordered by revenue descending.
--Add appropriate error handling for invalid date ranges where @start_date is later than @end_
DROP PROCEDURE IF EXISTS sales.usp_store_sales_report;
GO

CREATE PROCEDURE sales.usp_store_sales_report
    @store_id INT, @start_date DATE, @end_date DATE
AS
BEGIN
    IF @start_date > @end_date
        THROW 50001, 'Invalid date range.', 1;

    SELECT p.product_name,
           SUM(oi.quantity) AS total_units_sold,
           SUM(oi.quantity * oi.list_price) AS total_net_revenue
    FROM sales.orders o
    JOIN sales.order_items oi ON o.order_id = oi.order_id
    JOIN production.products p ON oi.product_id = p.product_id
    WHERE o.store_id = @store_id
      AND o.order_status = 4
      AND o.order_date BETWEEN @start_date AND @end_date
    GROUP BY p.product_name
    ORDER BY total_net_revenue DESC;
END;
GO








--Task 10 — Management Insight Query (3 marks)
--Write one additional SQL query that you believe would provide useful insight to BikeStores management using at least three tables.

--Below the query, add a SQL comment of no more than three lines explaining:
--1. the business question,
--2. what the result measures, and
--3. why management should care about it.


SELECT s.store_name, p.product_name,
SUM(oi.quantity) AS units_sold,
SUM(oi.quantity * oi.list_price) AS revenue
FROM sales.orders o
JOIN sales.order_items oi ON 
o.order_id = oi.order_id
JOIN production.products p ON 
oi.product_id = p.product_id
JOIN sales.stores s ON 
o.store_id = s.store_id
GROUP BY s.store_name,
p.product_name
ORDER BY revenue DESC;

-- Business question: Which products generate the most sales in each store?
-- Measures: Total units sold and revenue by store and product.
-- Management can use this to identify strong products and improve stock planning.

----------COMPLETE ASSIGNMENT----------------- 