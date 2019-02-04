-----------------------------------------
-- Demo script for Parameter sniffing --
-----------------------------------------

-- Create demo billing table 
DROP TABLE BillingInfo
go

CREATE TABLE BillingInfo(
ID INT IDENTITY,
BillingDate DATETIME,
BillingAmt FLOAT,
BillingDesc varchar(500)
)
GO

-- Insert data in billing table 
DECLARE @I INT
DECLARE @BD INT
SET @I = 0
WHILE @I < 1000000
BEGIN
SET @I = @I + 1
SET @BD=CAST(RAND()*10000 AS INT)%3650
INSERT BillingInfo (BillingDate, BillingAmt)
VALUES (DATEADD(DD,@BD,
CAST('1999/01/01' AS DATETIME)),
RAND()*5000)
END
GO

select count(*) from BillingInfo

-- Create indexes on billing table
ALTER TABLE BillingInfo ADD CONSTRAINT [PK_BillingInfo_ID]
PRIMARY KEY CLUSTERED (ID)
GO

CREATE NONCLUSTERED INDEX IX_BillingDate ON dbo.BillingInfo(BillingDate)
GO

-- Create stored procedure to select data from billing table
DROP PROCEDURE [DisplayBillingInfo]
GO 
CREATE PROC [dbo].[DisplayBillingInfo]
@BeginDate DATETIME,
@EndDate DATETIME
AS
SELECT BillingDate, BillingAmt
FROM BillingInfo
WHERE BillingDate between @BeginDate AND @EndDate
GO



-- Execute stored procedure after resetting procedure cache (index scan)
SET STATISTICS IO ON;
DBCC FREEPROCCACHE;
EXEC dbo.DisplayBillingInfo
@BeginDate = '1999-01-01', 
@EndDate = '1999-12-31';

-- Re-execute sproc with different parameters.
EXEC dbo.DisplayBillingInfo
@BeginDate = '2005-01-01', 
@EndDate = '2005-01-03';
-- Swapped the order of the two different EXEC statements. 
-- This way the first EXEC statement now calls the stored procedure using the smaller date range as parameters. 
-- This short date range will be the one that are sniffed in order to create the compiled execution plan. 
-- When I run this test, here is the execution plan that each stored procedure execution will use:


-- Execute sproc with different parameters (index seek)
SET STATISTICS IO ON;
DBCC FREEPROCCACHE;
EXEC dbo.DisplayBillingInfo
@BeginDate = '2005-01-01', 
@EndDate = '2005-01-03';
-- Re-execute sproc with different parameters.
EXEC dbo.DisplayBillingInfo
@BeginDate = '1999-01-01', 
@EndDate = '1999-12-31';

-- Action
-- RECOMPILE at procedure level

DROP PROC [dbo].[DisplayBillingInfo]
GO
CREATE PROC [dbo].[DisplayBillingInfo]
@BeginDate DATETIME,
@EndDate DATETIME
WITH RECOMPILE
AS
SELECT BillingDate, BillingAmt
FROM BillingInfo
WHERE BillingDate between @BeginDate AND @EndDate; 
GO

-- Index seek
DBCC FREEPROCCACHE;
EXEC dbo.DisplayBillingInfo
@BeginDate = '2005-01-01', 
@EndDate = '2005-01-03';
-- Index scan
EXEC dbo.DisplayBillingInfo
@BeginDate = '1999-01-01', 
@EndDate = '1999-12-31';

-- RECOMPILE at query level

DROP PROC [dbo].[DisplayBillingInfo]
GO
CREATE PROC [dbo].[DisplayBillingInfo]
@BeginDate DATETIME,
@EndDate DATETIME
WITH RECOMPILE
AS
DECLARE @StartDate DATETIME;
DECLARE @StopDate DATETIME;
SET @StartDate = @BeginDate;
SET @StopDate = @EndDate;
SELECT BillingDate, BillingAmt
FROM BillingInfo
WHERE BillingDate between @StartDate AND @StopDate
OPTION (RECOMPILE)
GO

-- Index seek
DBCC FREEPROCCACHE;
EXEC dbo.DisplayBillingInfo
@BeginDate = '2005-01-01', 
@EndDate = '2005-01-03';
-- Index scan
EXEC dbo.DisplayBillingInfo
@BeginDate = '1999-01-01', 
@EndDate = '1999-12-31';
