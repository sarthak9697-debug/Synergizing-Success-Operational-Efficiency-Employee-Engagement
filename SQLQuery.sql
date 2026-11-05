/*==============================================================
  0. VERIFY THE IMPORTED TABLE
==============================================================*/
IF OBJECT_ID(N'dbo.Business_Operations_Dataset', N'U') IS NULL
BEGIN
    THROW 50001,
      'Table dbo.Business_Operations_Dataset was not found. Import the Business_Operations_Dataset.csv file into this database first.',
      1;
END
GO

SELECT TOP (10) *
FROM [dbo].[Business_Operations_Dataset];
GO

SELECT COUNT_BIG(*) AS TotalRows
FROM [dbo].[Business_Operations_Dataset];
GO

/*==============================================================
  1. ADD A STABLE ROW ID FOR THE REVENUE AUDIT TRIGGER
==============================================================*/
IF COL_LENGTH(N'dbo.Business_Operations_Dataset', N'business_record_id') IS NULL
BEGIN
    ALTER TABLE [dbo].[Business_Operations_Dataset]
    ADD business_record_id BIGINT IDENTITY(1,1) NOT NULL;
END;
GO

/* Create a unique index on the new row ID if it does not exist. */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'UX_BusinessOperations_RecordID'
      AND object_id = OBJECT_ID(N'dbo.Business_Operations_Dataset')
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_BusinessOperations_RecordID
    ON [dbo].[Business_Operations_Dataset](business_record_id);
END;
GO

/*==============================================================
  2. BUSINESS ANALYSIS QUERIES
==============================================================*/

-- Q1. Department with the highest average product profit margin.
SELECT TOP (1)
    department,
    AVG(CAST(profit_margin AS DECIMAL(18,4))) AS avg_profit_margin
FROM [dbo].[Business_Operations_Dataset]
GROUP BY department
ORDER BY avg_profit_margin DESC, department;
GO

-- Q2. Highest-performing employee record in the IT department.
SELECT TOP (1)
    employee_id,
    employee_name,
    employee_role,
    employee_performance_score
FROM [dbo].[Business_Operations_Dataset]
WHERE department = 'IT'
ORDER BY employee_performance_score DESC, employee_name;
GO

-- Q3. Product with the highest revenue in the HR department.
SELECT TOP (1)
    product_id,
    product_name,
    revenue
FROM [dbo].[Business_Operations_Dataset]
WHERE department = 'HR'
ORDER BY revenue DESC, product_name;
GO

-- Q4a. Average customer feedback score for Accessories.
SELECT
    AVG(CAST(customer_feedback_score AS DECIMAL(10,2))) AS AverageFeedbackScore
FROM [dbo].[Business_Operations_Dataset]
WHERE category = 'Accessories';
GO

-- Q4b. Accessories product with the highest customer feedback score.
SELECT TOP (1)
    product_id,
    product_name,
    customer_feedback_score
FROM [dbo].[Business_Operations_Dataset]
WHERE category = 'Accessories'
ORDER BY customer_feedback_score DESC, product_name;
GO

-- Q5. Supplier with the highest total inventory across all records.
SELECT TOP (1)
    supplier_id,
    supplier_name,
    SUM(CAST(inventory_level AS BIGINT)) AS TotalInventoryLevel
FROM [dbo].[Business_Operations_Dataset]
GROUP BY supplier_id, supplier_name
ORDER BY TotalInventoryLevel DESC, supplier_name;
GO

-- Q6. Product in the Gadgets category with the lowest inventory.
SELECT TOP (1)
    product_id,
    product_name,
    inventory_level
FROM [dbo].[Business_Operations_Dataset]
WHERE category = 'Gadgets'
ORDER BY inventory_level ASC, product_name;
GO

-- Q7. Sales training completion.
-- Employee IDs occur on multiple rows and some have inconsistent training flags.
-- This query counts each employee_id once and treats an employee as trained
-- if at least one of their records has training_program_completed = 1.
WITH SalesEmployeeTraining AS
(
    SELECT
        employee_id,
        MAX(CASE WHEN training_program_completed = 1 THEN 1 ELSE 0 END) AS IsTrained
    FROM [dbo].[Business_Operations_Dataset]
    WHERE department = 'Sales'
    GROUP BY employee_id
)
SELECT
    COUNT(*) AS TotalSalesEmployees,
    SUM(IsTrained) AS TrainedSalesEmployees,
    CAST(100.0 * SUM(IsTrained) / NULLIF(COUNT(*), 0) AS DECIMAL(10,2))
        AS PercentageTrained
FROM SalesEmployeeTraining;
GO

-- Q8a. Total units sold in Marketing.
SELECT
    SUM(CAST(units_sold AS BIGINT)) AS TotalUnitsSoldMarketing
FROM [dbo].[Business_Operations_Dataset]
WHERE department = 'Marketing';
GO

-- Q8b. Marketing product record with the highest units sold.
SELECT TOP (1)
    product_id,
    product_name,
    units_sold
FROM [dbo].[Business_Operations_Dataset]
WHERE department = 'Marketing'
ORDER BY units_sold DESC, product_name;
GO

/*==============================================================
  3. ADVANCED SQL
==============================================================*/

-- Q9. Rank employees within each department by total revenue.
-- Aggregate first because an employee can appear on multiple product rows.
WITH EmployeeRevenue AS
(
    SELECT
        department,
        employee_id,
        employee_name,
        SUM(revenue) AS total_revenue
    FROM [dbo].[Business_Operations_Dataset]
    GROUP BY department, employee_id, employee_name
)
SELECT
    department,
    employee_id,
    employee_name,
    total_revenue,
    DENSE_RANK() OVER
    (
        PARTITION BY department
        ORDER BY total_revenue DESC
    ) AS RevenueRank
FROM EmployeeRevenue
ORDER BY department, RevenueRank, employee_name;
GO

-- Q10. Departments with average salary above $70,000.
WITH DepartmentAverageSalary AS
(
    SELECT
        department,
        AVG(CAST(salary AS DECIMAL(18,2))) AS AverageSalary
    FROM [dbo].[Business_Operations_Dataset]
    GROUP BY department
)
SELECT
    department,
    AverageSalary
FROM DepartmentAverageSalary
WHERE AverageSalary > 70000
ORDER BY AverageSalary DESC;
GO

/*==============================================================
  4. VIEW: ACCESSORIES PRODUCT PERFORMANCE
==============================================================*/
CREATE OR ALTER VIEW dbo.Accessories_Product_Performance
AS
SELECT
    product_id,
    product_name,
    revenue,
    profit_margin
FROM [dbo].[Business_Operations_Dataset]
WHERE category = 'Accessories';
GO

SELECT *
FROM dbo.Accessories_Product_Performance;
GO

/*==============================================================
  5. NONCLUSTERED INDEX ON EMPLOYEE_NAME
==============================================================*/
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'idx_employee_name'
      AND object_id = OBJECT_ID(N'dbo.Business_Operations_Dataset')
)
BEGIN
    CREATE NONCLUSTERED INDEX idx_employee_name
    ON [dbo].[Business_Operations_Dataset](employee_name);
END;
GO

/*==============================================================
  6. STORED PROCEDURE: DEPARTMENT REVENUE
==============================================================*/
CREATE OR ALTER PROCEDURE dbo.GetDepartmentRevenue
    @DepartmentName VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        department,
        SUM(revenue) AS total_revenue
    FROM [dbo].[Business_Operations_Dataset]
    WHERE department = @DepartmentName
    GROUP BY department;
END;
GO

-- Example execution.
EXEC dbo.GetDepartmentRevenue @DepartmentName = 'Sales';
GO

/*==============================================================
  7. REVENUE CHANGE AUDIT TABLE AND TRIGGER
==============================================================*/
IF OBJECT_ID(N'dbo.RevenueChangeLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.RevenueChangeLog
    (
        log_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        business_record_id BIGINT NOT NULL,
        product_id INT NULL,
        employee_id INT NULL,
        old_revenue FLOAT NULL,
        new_revenue FLOAT NULL,
        changed_at DATETIME2(0) NOT NULL
            CONSTRAINT DF_RevenueChangeLog_changed_at DEFAULT SYSDATETIME(),
        changed_by SYSNAME NOT NULL
            CONSTRAINT DF_RevenueChangeLog_changed_by DEFAULT SUSER_SNAME()
    );
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_LogRevenueChanges
ON dbo.[Business_Operations_Dataset]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.RevenueChangeLog
    (
        business_record_id,
        product_id,
        employee_id,
        old_revenue,
        new_revenue,
        changed_by
    )
    SELECT
        d.business_record_id,
        i.product_id,
        i.employee_id,
        d.revenue,
        i.revenue,
        SUSER_SNAME()
    FROM deleted AS d
    INNER JOIN inserted AS i
        ON d.business_record_id = i.business_record_id
    WHERE
        (d.revenue <> i.revenue)
        OR (d.revenue IS NULL AND i.revenue IS NOT NULL)
        OR (d.revenue IS NOT NULL AND i.revenue IS NULL);
END;
GO

-- Verify trigger status and audit table.
SELECT
    name,
    is_disabled
FROM sys.triggers
WHERE name = N'trg_LogRevenueChanges';
GO

SELECT TOP (20) *
FROM dbo.RevenueChangeLog
ORDER BY log_id DESC;
GO

/*==============================================================
  8. SCALAR UDF: CALCULATE PROFIT
==============================================================*/
CREATE OR ALTER FUNCTION dbo.CalculateProfit
(
    @revenue FLOAT,
    @profit_margin FLOAT
)
RETURNS FLOAT
AS
BEGIN
    IF @revenue IS NULL OR @profit_margin IS NULL
        RETURN NULL;

    RETURN (@revenue * @profit_margin) / 100.0;
END;
GO

SELECT
    product_name,
    revenue,
    profit_margin,
    dbo.CalculateProfit(revenue, profit_margin) AS profit
FROM [dbo].[Business_Operations_Dataset];
GO

/*==============================================================
  9. CLUSTERED INDEX ON COMPANY_ID
==============================================================*/
-- company_id has repeated values in the supplied dataset.
-- A non-unique clustered index is valid, but SQL Server permits only
-- one clustered index per table. Create it only if none exists.
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Business_Operations_Dataset')
      AND type = 1
)
BEGIN 
    CREATE CLUSTERED INDEX idx_company_id
    ON [dbo].[Business_Operations_Dataset](company_id);
END
ELSE
BEGIN
    PRINT 'A clustered index already exists. Skipping idx_company_id creation.';
END;
GO

/*==============================================================
  10. FINAL OBJECT AND INDEX VERIFICATION
==============================================================*/
SELECT
    name AS IndexName,
    type_desc AS IndexType
FROM sys.indexes
WHERE object_id = OBJECT_ID(N'dbo.Business_Operations_Dataset')
  AND name IS NOT NULL
ORDER BY type_desc, name;
GO

SELECT
    OBJECT_SCHEMA_NAME(object_id) AS SchemaName,
    name AS ObjectName,
    type_desc AS ObjectType
FROM sys.objects
WHERE name IN
(
    N'Accessories_Product_Performance',
    N'GetDepartmentRevenue',
    N'CalculateProfit',
    N'RevenueChangeLog',
    N'trg_LogRevenueChanges'
)
ORDER BY type_desc, name;
GO