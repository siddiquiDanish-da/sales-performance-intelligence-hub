-- Drop if exists and recreate cleanly
	DROP TABLE IF EXISTS orders;
	DROP TABLE IF EXISTS customers;
	DROP TABLE IF EXISTS products;
	DROP TABLE IF EXISTS regions;
	
	-- Create Regions
	CREATE TABLE regions (
	    RegionID   VARCHAR(5) PRIMARY KEY,
	    RegionName VARCHAR(50),
	    Country    VARCHAR(50),
	    Continent  VARCHAR(50)
	);
	
	-- Create Customers
	CREATE TABLE customers (
	    CustomerID   VARCHAR(10) PRIMARY KEY,
	    CustomerName VARCHAR(100),
	    Email        VARCHAR(100),
	    Segment      VARCHAR(20),
	    City         VARCHAR(50),
	    JoinDate     DATE,
	    RegionID     VARCHAR(5)
	);
	
	-- Create Products
	CREATE TABLE products (
	    ProductID    VARCHAR(10) PRIMARY KEY,
	    ProductName  VARCHAR(200),
	    Category     VARCHAR(50),
	    CostPrice    NUMERIC(10,2),
	    SellingPrice NUMERIC(10,2)
	);
	
	-- Create Orders (NO FOREIGN KEY — keeps it simple!)
	CREATE TABLE orders (
	    OrderID     VARCHAR(10) PRIMARY KEY,
	    CustomerID  VARCHAR(10),
	    ProductID   VARCHAR(10),
	    RegionID    VARCHAR(5),
	    OrderDate   DATE,
	    Quantity    INT,
	    UnitPrice   NUMERIC(10,2),
	    Discount    NUMERIC(5,4),
	    Channel     VARCHAR(50),
	    OrderStatus VARCHAR(20),
	    Revenue     NUMERIC(12,2),
	    Profit      NUMERIC(12,2)
	);
	
	
	-- Verify tables created
	SELECT table_name 
	FROM information_schema.tables
	WHERE table_schema = 'public';
	
	select * from regions;
	select * from customers;
	select * from orders;
	select * from products;
	
	
	--to check all tables have correct data-- 
	SELECT 'regions'   AS Table_Name, COUNT(*) AS Total_Rows FROM regions
	UNION ALL
	SELECT 'customers', COUNT(*) FROM customers
	UNION ALL
	SELECT 'products',  COUNT(*) FROM products
	UNION ALL
	SELECT 'orders',    COUNT(*) FROM orders;
	
	-- This combines all 4 tables into one unified view
	-- JOIN is like merging 4 Excel sheets using a common column
	SELECT 
	    o.OrderID,
	    o.OrderDate,
	    c.CustomerName,
	    c.Segment AS CustomerSegment,
	    p.ProductName,
	    p.Category AS ProductCategory,
	    r.RegionName,
	    r.Country,
	    r.Continent,
	    o.Channel,
	    o.Quantity,
	    o.UnitPrice,
	    o.Discount,
	    o.Revenue,
	    o.Profit,
	    o.OrderStatus
	FROM Orders o
	JOIN Customers c ON o.CustomerID = c.CustomerID
	JOIN Products p ON o.ProductID = p.ProductID
	JOIN Regions r ON o.RegionID = r.RegionID;

-- The 5 Executive KPIs for your dashboard
	SELECT 
	    COUNT(DISTINCT o.OrderID)                          AS Total_Orders,
	    COUNT(DISTINCT o.CustomerID)                       AS Total_Customers,
	    ROUND(SUM(o.Revenue), 2)                           AS Total_Revenue,
	    ROUND(SUM(o.Profit) / SUM(o.Revenue) * 100, 2)    AS Profit_Margin_Percent,
	    ROUND(SUM(o.Revenue) / COUNT(DISTINCT o.OrderID), 2) AS Avg_Order_Value
	FROM Orders o;

		-- CTE = Common Table Expression (like creating a temporary table inside the query)
	-- YoY Growth = how much did we grow compared to last year?
	-- CTE: Year-over-Year Revenue Growth (PostgreSQL version)
	WITH YearlyRevenue AS (
	    SELECT 
	        EXTRACT(YEAR FROM OrderDate)    AS Year,
	        ROUND(SUM(Revenue)::NUMERIC, 2) AS Total_Revenue,
	        ROUND(SUM(Profit)::NUMERIC, 2)  AS Total_Profit
	    FROM orders
	    GROUP BY EXTRACT(YEAR FROM OrderDate)
	)
	SELECT 
	    curr.Year,
	    curr.Total_Revenue        AS Current_Revenue,
	    prev.Total_Revenue        AS Previous_Revenue,
	    ROUND(
	        ((curr.Total_Revenue - prev.Total_Revenue) / prev.Total_Revenue * 100)::NUMERIC
	    , 2)     AS YoY_Growth_Percent
	FROM YearlyRevenue curr
	LEFT JOIN YearlyRevenue prev ON curr.Year = prev.Year + 1
	ORDER BY curr.Year;

		-- Window Functions work "across rows" without collapsing them
	-- RANK() gives a ranking number to each region by revenue
	SELECT 
		r.RegionName,
		r.Country,
		ROUND(SUM(o.Revenue), 2) AS Total_Revenue,
		RANK() OVER (ORDER BY SUM(o.Revenue) DESC) AS Revenue_Rank,
		ROUND(SUM(o.Revenue) / SUM(SUM(o.Revenue)) OVER () * 100, 2) AS Revenue_Share_Percent
	FROM Orders o
	JOIN Regions r ON o.RegionID = r.RegionID
	GROUP BY r.RegionName, r.Country;

	--FINding SAles by Category
		SELECT 
	    p.Category,
	    COUNT(o.OrderID)         AS Total_Orders,
	    ROUND(SUM(o.Revenue), 2) AS Total_Revenue,
	    ROUND(SUM(o.Profit), 2)  AS Total_Profit,
	    ROUND(SUM(o.Profit)/SUM(o.Revenue)*100, 2) AS Profit_Margin_Pct
	FROM Orders o
	JOIN Products p ON o.ProductID = p.ProductID
	GROUP BY p.Category
	ORDER BY Total_Revenue DESC;

	--Finding Top 5 Products by Revenue
		SELECT 
	    p.ProductName,
	    p.Category,
	    COUNT(o.OrderID)         AS Orders_Count,
	    ROUND(SUM(o.Revenue), 2) AS Total_Revenue,
	    ROUND(SUM(o.Profit), 2)  AS Total_Profit
	FROM Orders o
	JOIN Products p ON o.ProductID = p.ProductID
	GROUP BY p.ProductName, p.Category
	ORDER BY Total_Revenue DESC
	LIMIT 5;

--Finding Sales by Channel
	SELECT 
	    Channel,
	    COUNT(OrderID)              AS Total_Orders,
	    ROUND(SUM(Revenue), 2)      AS Total_Revenue,
	    ROUND(AVG(Revenue), 2)      AS Avg_Revenue_Per_Order,
	    ROUND(SUM(Revenue)/
	        (SELECT SUM(Revenue) FROM Orders)*100, 2) AS Channel_Contribution_Pct
	FROM Orders
	GROUP BY Channel
	ORDER BY Total_Revenue DESC;

	--Finding Customer Segment Revenue
		SELECT 
	    c.Segment,
	    COUNT(DISTINCT c.CustomerID) AS Total_Customers,
	    COUNT(o.OrderID)              AS Total_Orders,
	    ROUND(SUM(o.Revenue), 2)      AS Total_Revenue,
	    ROUND(AVG(o.Revenue), 2)      AS Avg_Order_Value
	FROM Orders o
	JOIN Customers c ON o.CustomerID = c.CustomerID
	GROUP BY c.Segment
	ORDER BY Total_Revenue DESC;

	--findINg  Monthly Sales Trend
	-- Monthly Sales Trend (PostgreSQL)
	SELECT 
	    TO_CHAR(OrderDate, 'YYYY-MM')         AS Month,
	    TO_CHAR(OrderDate, 'Month')           AS Month_Name,
	    EXTRACT(YEAR FROM OrderDate)          AS Year,
	    COUNT(OrderID)                        AS Total_Orders,
	    ROUND(SUM(Revenue)::NUMERIC, 2)       AS Monthly_Revenue,
	    ROUND(SUM(Profit)::NUMERIC, 2)        AS Monthly_Profit,
	    ROUND(AVG(Revenue)::NUMERIC, 2)       AS Avg_Order_Value
	FROM orders
	GROUP BY 
	    TO_CHAR(OrderDate, 'YYYY-MM'),
	    TO_CHAR(OrderDate, 'Month'),
	    EXTRACT(YEAR FROM OrderDate)
	ORDER BY Month;

	-- Finding Order Status Distribution
	SELECT 
	    OrderStatus,
	    COUNT(OrderID) AS Total_Orders,
	    ROUND(SUM(Revenue), 2) AS Revenue,
	    ROUND(COUNT(OrderID) * 100.0 / (SELECT COUNT(*) FROM Orders), 2) AS Status_Pct
	FROM Orders
	GROUP BY OrderStatus;
