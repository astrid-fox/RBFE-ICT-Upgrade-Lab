-- ============================================================================
-- RBFE Legacy Database Migration & RBAC Security Script (RBFE-SQL01)
-- Enforces Least Privilege between Retail/Warehouse Inventory & Accounts Payroll
-- ============================================================================

USE master;
GO

-- 1. Create Migrated Databases
CREATE DATABASE RBFE_Inventory;
GO
CREATE DATABASE RBFE_Payroll;
GO

-- 2. Create Sample Inventory Table for Café & Warehouse Operations
USE RBFE_Inventory;
GO
CREATE TABLE ProductStock (
    ProductID INT PRIMARY KEY IDENTITY(1,1),
    ProductName NVARCHAR(100) NOT NULL,
    OriginFarm NVARCHAR(100) DEFAULT 'Donnybrook Orchard',
    StockQty INT NOT NULL,
    LastUpdated DATETIME DEFAULT GETDATE()
);

INSERT INTO ProductStock (ProductName, StockQty)
VALUES ('Donnybrook Strawberry Jam 350g', 450),
       ('Freshly Baked Apple & Berry Pie', 120),
       ('Artisan Plum Preserve 500g', 310);
GO

-- 3. Map Active Directory Security Groups to Least-Privilege SQL Roles
USE master;
GO
CREATE LOGIN [RBFE\GRP_Retail_Cafes] FROM WINDOWS;
CREATE LOGIN [RBFE\GRP_Warehouse]    FROM WINDOWS;
CREATE LOGIN [RBFE\GRP_Accounts_HR_IT] FROM WINDOWS;
GO

-- Grant Retail & Warehouse read/write ONLY to Inventory (Zero access to Payroll)
USE RBFE_Inventory;
GO
CREATE USER [RBFE\GRP_Retail_Cafes] FOR LOGIN [RBFE\GRP_Retail_Cafes];
CREATE USER [RBFE\GRP_Warehouse]    FOR LOGIN [RBFE\GRP_Warehouse];
ALTER ROLE db_datareader ADD MEMBER [RBFE\GRP_Retail_Cafes];
ALTER ROLE db_datawriter ADD MEMBER [RBFE\GRP_Retail_Cafes];
ALTER ROLE db_datareader ADD MEMBER [RBFE\GRP_Warehouse];
ALTER ROLE db_datawriter ADD MEMBER [RBFE\GRP_Warehouse];
GO

-- Grant Accounts/HR exclusive access to Payroll Database
USE RBFE_Payroll;
GO
CREATE USER [RBFE\GRP_Accounts_HR_IT] FOR LOGIN [RBFE\GRP_Accounts_HR_IT];
ALTER ROLE db_owner ADD MEMBER [RBFE\GRP_Accounts_HR_IT];
GO
