-- INDEX
--#####################################################################################################################

--SAMPLES 
-- DEMO 1 

drop table Persons
go

-- Primary Key creation 
CREATE TABLE Persons
(
P_Id int NOT NULL,
LastName varchar(255) NOT NULL,
FirstName varchar(255),
Address varchar(255),
City varchar(255),
CONSTRAINT pk_Person PRIMARY KEY (P_Id,LastName )
)

SELECT * FROM sys.indexes WHERE name = 'pk_Person'


DROP TABLE Persons
GO

CREATE TABLE Persons
(
P_Id int NOT NULL,
LastName varchar(255) NOT NULL,
FirstName varchar(255),
Address varchar(255),
City varchar(255)
)

ALTER TABLE Persons
ADD PRIMARY KEY (P_Id)

SELECT * FROM sys.indexes WHERE name like '%person%'

ALTER TABLE Persons DROP CONSTRAINT PK__Persons__A3420A5763E624C1


ALTER TABLE Persons
ADD CONSTRAINT pk_Person PRIMARY KEY (P_Id )

SELECT * FROM sys.indexes WHERE name = 'pk_Person'

--------------------------------
-- Create Non-Clustered Index --
---------------------------------
DROP INDEX persons.IX_person_name


CREATE NONCLUSTERED INDEX IX_person_name 
ON persons (LastName)
INCLUDE (FirstName)


--------------------------------
-- Checking index details --
---------------------------------
SELECT * FROM sys.indexes WHERE name = 'IX_person_name'

SELECT * FROM sys.index_columns WHERE object_id = 1349579846


--------------------
-- Demo 2 Scripts --
--------------------

-------------------------------------
-- Index column Order Demo Script --
-------------------------------------


----------------------------------------------------------------------
-- Example : Query plan changes with index and Key Look up concept --
----------------------------------------------------------------------

DROP TABLE dbo.TABLE1
GO

-- Test Table Creation

CREATE TABLE [dbo].[TABLE1] 
([col1] [int] NOT NULL,[col2] [int] NULL,[col3] [int] NULL,[col4] [varchar](50) NULL)
GO

ALTER TABLE dbo.TABLE1 ADD CONSTRAINT PK_TABLE1 PRIMARY KEY CLUSTERED (col1) 
GO


-- Populate tables
DECLARE @val INT
SELECT @val=1
WHILE @val < 1000
BEGIN 
INSERT INTO dbo.Table1(col1, col2, col3, col4) VALUES(@val,@val,@val,'TEST')
SELECT @val=@val+1
END
GO

-- Create multi-column index on table1
CREATE NONCLUSTERED INDEX IX_TABLE1_col2col3 ON dbo.TABLE1 (col2,col3)
WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, 
ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
ON [PRIMARY]
GO


DBCC DROPCLEANBUFFERS
GO
SET STATISTICS IO ON
SELECT * FROM dbo.TABLE1 WHERE col1=88
SET STATISTICS IO OFF
GO


DBCC DROPCLEANBUFFERS
GO
SET STATISTICS IO ON
SELECT * FROM dbo.TABLE1 WHERE col2=88
SET STATISTICS IO OFF
GO

------------------------------------------
-- Example 2 : I/O Cost with column order 
------------------------------------------

DROP TABLE dbo.TABLE2
GO

CREATE TABLE [dbo].[TABLE2] 
([col1] [int] NOT NULL,[col2] [int] NULL,[col3] [int] NULL,[col4] [varchar](50) NULL)
GO

CREATE INDEX idx_Test ON TABLE2 (Col2, Col1, Col3)
GO


-- Populate tables
DECLARE @val INT
SELECT @val=1
WHILE @val < 1000
BEGIN 
INSERT INTO dbo.Table2(col1, col2, col3, col4) VALUES(@val,@val,@val,'TEST')
SELECT @val=@val+1
END
GO

SET STATISTICS IO ON

SELECT 1
FROM dbo.Table2
WHERE Col1 = 12
AND Col2 = 12
AND Col3 = 12

SELECT 1
FROM dbo.Table2
WHERE Col3 = 12

SET STATISTICS IO OFF

--#####################################################################################################################
------------------------
--- Un-used Indexes ---
------------------------

SELECT OBJECT_SCHEMA_NAME(i.object_id) AS SchemaName ,
OBJECT_NAME(i.object_id) AS TableName ,
i.name ,
ius.user_seeks ,
ius.user_scans ,
ius.user_lookups ,
ius.user_updates
FROM sys.dm_db_index_usage_stats AS ius
JOIN sys.indexes AS i ON i.index_id = ius.index_id
AND i.object_id = ius.object_id
WHERE ius.database_id = DB_ID()
AND i.is_unique_constraint = 0 -- no unique indexes
AND i.is_primary_key = 0
AND i.is_disabled = 0
AND i.type > 1 -- don't consider heaps/clustered index
AND ( ( ius.user_seeks + ius.user_scans +
ius.user_lookups ) < ius.user_updates
OR ( ius.user_seeks = 0
AND ius.user_scans = 0
)
)

-- More information about (all) indexes
-- we can filer out data for the un-used indexes based on last_user_seek / last_user_scan

SELECT d.name AS 'database name', t.name AS 'table name', i.name AS 'index name', ius.*
FROM sys.dm_db_index_usage_stats ius
JOIN sys.databases d ON d.database_id = ius.database_id AND ius.database_id=db_id()
JOIN sys.tables t ON t.object_id = ius.object_id
JOIN sys.indexes i ON i.object_id = ius.object_id AND i.index_id = ius.index_id
ORDER BY user_updates DESC

--#####################################################################################################################
------------------------
--- Missing Indexes ---
------------------------

SELECT migs.avg_total_user_cost * ( migs.avg_user_impact / 100.0 )
* ( migs.user_seeks + migs.user_scans ) AS improvement_measure ,
'CREATE INDEX [missing_index_'
+ CONVERT (VARCHAR, mig.index_group_handle) + '_'
+ CONVERT (VARCHAR, mid.index_handle) + '_'
+ LEFT(PARSENAME(mid.statement, 1), 32) + ']' + ' ON '
+ mid.statement
+ ' (' + ISNULL(mid.equality_columns, '')
+ CASE WHEN mid.equality_columns IS NOT NULL
AND mid.inequality_columns IS NOT NULL THEN ','
ELSE ''
END + ISNULL(mid.inequality_columns, '') + ')'
+ ISNULL(' INCLUDE ('
+ mid.included_columns
+ ')', '')
AS create_index_statement ,
migs.* ,
mid.database_id ,
mid.[object_id]
FROM sys.dm_db_missing_index_groups mig
INNER JOIN sys.dm_db_missing_index_group_stats migs
ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid
ON mig.index_handle = mid.index_handle
WHERE migs.avg_total_user_cost * ( migs.avg_user_impact / 100.0 )
* ( migs.user_seeks + migs.user_scans ) > 10
ORDER BY migs.avg_total_user_cost * migs.avg_user_impact
* ( migs.user_seeks + migs.user_scans ) DESC


-- Another query which gives similar information
select d.name AS DatabaseName, mid.*
from sys.dm_db_missing_index_details mid
join sys.databases d ON mid.database_id=d.database_id


----------------------
--- XML Show Plan ---
----------------------

SET SHOWPLAN_XML ON

SELECT * FROM dbo.TABLE1 WHERE col2=88


SET SHOWPLAN_XML OFF


--------------------
-- Demo 3 Scripts --
--------------------

--#####################################################################################################################
-------------------------------------
-- Index Fragmentation Demo Script --
-------------------------------------

SELECT OBJECT_NAME(ind.OBJECT_ID) AS TableName, 
ind.name AS IndexName, indexstats.index_type_desc AS IndexType, 
indexstats.avg_fragmentation_in_percent 
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) indexstats 
INNER JOIN sys.indexes ind 
ON ind.object_id = indexstats.object_id 
AND ind.index_id = indexstats.index_id 
WHERE indexstats.avg_fragmentation_in_percent > 30 
ORDER BY indexstats.avg_fragmentation_in_percent DESC


--#####################################################################################################################
--------------------
-- Index Rebuild --
--------------------

ALTER INDEX PK_TABLE2 ON dbo.TABLE2
REBUILD;
GO

-- Rebuild all indexes on the table.
ALTER INDEX ALL ON dbo.TABLE1
REBUILD WITH (FILLFACTOR = 80, SORT_IN_TEMPDB = ON,
STATISTICS_NORECOMPUTE = ON);
GO

--#####################################################################################################################
-----------------------
-- Index Reorganize --
-----------------------
ALTER INDEX PK_TABLE2 ON dbo.TABLE2
REORGANIZE ; 
GO

-- Reorganize all indexes on the table.
ALTER INDEX ALL ON dbo.TABLE1
REORGANIZE ; 
GO


-- You'll want to run this after your server has been up and running a normal workload for a while.  If this returns no results, that's good news and indicates that you're not missing any indexes that are obvious enough for the DMV to detect.  If it does return some suggestions, even better: you just improved your server's perf with almost no work.

-- While to me this feature is so cool it almost seems magical, it does have a few limitations you should be aware of:

-- It's not as smart as the Database Engine Tuning Advisor.  If you have identified a query that you know is expensive and needs some help, don't pass up DTA just because the missing index DMVs didn't have any suggestions.  DTA might still be able to help. 
-- The missing index DMVs don't take into account the overhead that new indexes can create (extra disk space, slight impact on insert/delete perf, etc). DTA does take this into account, however.
-- The "improvement_measure" column in this query's output is a rough indicator of the (estimated) improvement that might be seen if the index was created.  This is a unitless number, and has meaning only relative the same number for other indexes.  (It's a combination of the avg_total_user_cost, avg_user_impact, user_seeks, and user_scans columns in sys.dm_db_missing_index_group_stats.)
-- The missing index DMVs don't make recommendation about whether a proposed index should be clustered or nonclustered.  This has workload-wide ramifications, while these DMVs focus only on the indexes that would benefit individual queries.  (DTA can do this, however.)
-- Won't recommend partitioning.
-- It's possible that the DMVs may not recommend the ideal column order for multi-column indexes.
-- The DMV tracks information on no more than 500 missing indexes.
-- If you're a typical SQL user, you may not be using these DMVs yet.  If you look around, though, there are a few places where they are in use. One is in the SP2 Performance Dashboard reports.  Another is the Perf Stats Script that SQL PSS uses.  And if you think the missing index DMVs are useful, check out this set of scripts that builds on the missing index DMVs to simulate an "auto create index" feature.  Also, you should be aware there is similar missing index info output in the new XML showplan format in SQL 2005.  If you are already focused on a poorly-performing query, I would start with the plan view of missing indexes (followed by DTA) rather than the DMVs. 
