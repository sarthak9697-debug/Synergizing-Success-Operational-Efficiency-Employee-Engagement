# Business Operations & Employee Engagement — SQL Server Capstone

## Project description
Analyzed a multi-department business operations dataset using Microsoft SQL Server. The project explores department profitability, employee performance and training, product revenue, customer feedback, supplier inventory, and sales contribution.

## Dataset
- File: `data/Business_Operations_Dataset.csv` (also supplied as `.xlsx`)
- Rows: 5,000
- Columns: 30
- Departments: IT, Marketing, Sales, Production, HR
- Categories: Gadgets, Accessories, Electronics

## SQL skills demonstrated
- SELECT, filtering, sorting, GROUP BY and aggregate functions
- CASE expressions and safe percentage calculations with `NULLIF`
- CTEs and window functions (`DENSE_RANK`)
- Views, stored procedures and scalar user-defined functions
- Nonclustered and clustered indexes
- DML trigger and revenue-change audit logging
- Metadata checks and repeatable object creation

## Important dataset observations
- `company_id`, `product_id`, and `employee_id` are repeated across the 5,000 records.
- `company_id` is therefore not a unique key. The script adds `business_record_id` as an identity column so the revenue audit trigger can match updated rows safely.
- Some `employee_id` values have more than one `training_program_completed` value in the source data. The training query counts an employee once and treats the employee as trained if any of their Sales records has a value of 1.
- Employee IDs/names/roles can vary across records in the supplied synthetic dataset; interpret employee-level results with this limitation in mind.

## Run in SQL Server
1. Create or select a SQL Server database.
2. Import `data/Business_Operations_Dataset.csv` into that database.
3. Ensure the imported table name is exactly `Business_Operations_Dataset$` under schema `dbo`. If you use a different name, update the SQL script accordingly.
4. Open `sql/business_operations_capstone.sql` in SSMS.
5. Select the database containing the imported table and execute the script in order.
6. Review the result sets and verify the view, procedure, function, indexes and trigger.

The script is designed to be rerun. It creates the `business_record_id` column only once, checks indexes before creating them, and uses `CREATE OR ALTER` for programmable objects.

## Revenue audit trigger test
After the script runs, test the trigger on one record and then restore the original revenue:

```sql
DECLARE @RecordID BIGINT, @OriginalRevenue FLOAT;

SELECT TOP (1)
    @RecordID = business_record_id,
    @OriginalRevenue = revenue
FROM dbo.[Business_Operations_Dataset$]
ORDER BY business_record_id;

UPDATE dbo.[Business_Operations_Dataset$]
SET revenue = @OriginalRevenue + 1
WHERE business_record_id = @RecordID;

SELECT TOP (5) *
FROM dbo.RevenueChangeLog
ORDER BY log_id DESC;

UPDATE dbo.[Business_Operations_Dataset$]
SET revenue = @OriginalRevenue
WHERE business_record_id = @RecordID;
```

## GitHub repository layout
```text
business-operations-sql-capstone/
├── sql/
│   └── business_operations_capstone.sql
├── data/
│   ├── Business_Operations_Dataset.csv
│   └── Business_Operations_Dataset.xlsx
├── screenshots/
└── README.md
```

Add screenshots of the query results, view, stored procedure, indexes and trigger test to the `screenshots/` folder.

## Dataset scope clarification
The separately supplied K-12 School Shooting dataset (`DATA SET.xlsx` and `DATA SET IN CSV.csv`) is unrelated to this Business Operations & Employee Engagement project. Its Cover, Incident, Shooter, Victim and Weapon tables are not referenced by this SQL script. Keep that dataset in a separate repository/project if you intend to analyze it.
