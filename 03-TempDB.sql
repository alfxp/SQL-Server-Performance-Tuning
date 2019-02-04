--Tempdb Demo Scripts
------------------------------------------------------------------------
-- Tempdb : Find out space used by user objects --
--
--User table and index (created explicitly in tempdb)
--Global temporary table and index
--Local temporary table and index
--Table variable
------------------------------------------------------------------------
select convert(numeric(10,2),round(sum(data_pages)*8/1024.,2)) as user_object_reserved_MB
from tempdb.sys.allocation_units a
inner join tempdb.sys.partitions b on a.container_id = b.partition_id
inner join tempdb.sys.objects c on b.object_id = c.object_id


select * from tempdb.sys.objects
select * from tempdb.sys.allocation_units


drop table [#TABLE1]

CREATE TABLE [dbo].[#TABLE1] 
([col1] [int] NOT NULL,[col2] [int] NULL,[col3] [int] NULL,[col4] [varchar](50) NULL)
GO

-- Populate tables
DECLARE @val INT
SELECT @val=1
WHILE @val < 1000
BEGIN 
INSERT INTO dbo.#Table1(col1, col2, col3, col4) VALUES(@val,@val,@val,'TEST')
SELECT @val=@val+1
END
GO


select * 
from tempdb.sys.allocation_units a
inner join tempdb.sys.partitions b on a.container_id = b.partition_id
inner join tempdb.sys.objects c on b.object_id = c.object_id


------------------------------------------------------------------------
-- Tempdb : Find out space used by Internal Objects --
--
--Work tables
----Spooling, to hold intermediate results during a large query
----DBCC CHECKDB or DBCC CHECKTABLE
----Temporary large object storage (LOB)
----Processing SQL Service Broker Objects
----Common table expression
----Keyset-driven and static cursors

--Work files
----Hash join or hash aggregate operations
----Sort units

--ORDER BY, GROUP BY, UNION queries
----Index rebuilt or creation (with sort in tempdb is specified)

------------------------------------------------------------------------
select
reserved_MB=(unallocated_extent_page_count+version_store_reserved_page_count+user_object_reserved_page_count+internal_object_reserved_page_count+mixed_extent_page_count)*8/1024. ,
unallocated_extent_MB =unallocated_extent_page_count*8/1024., 
internal_object_reserved_page_count,
internal_object_reserved_MB =internal_object_reserved_page_count*8/1024.
from sys.dm_db_file_space_usage


------------------------------------------------------------------------
-- Tempdb : Find out space used for Version Store --
--
--Triggers
--MARS
--Online Index operation
--Row versioning-based transaction isolation level
----Read-committed isolation level (statement-level read consistency)
----Snapshot isolation level (transaction-level read consistency)
------------------------------------------------------------------------
select 
reserved_MB=(unallocated_extent_page_count+version_store_reserved_page_count+user_object_reserved_page_count+internal_object_reserved_page_count+mixed_extent_page_count)*8/1024. ,
unallocated_extent_MB =unallocated_extent_page_count*8/1024., 
version_store_reserved_page_count,
version_store_reserved_MB =version_store_reserved_page_count*8/1024.
from sys.dm_db_file_space_usage


------------------------------------------------------------------------
-- Files details associated with Tempdb.
------------------------------------------------------------------------
SELECT
name AS FileName,
size*1.0/128 AS FileSizeinMB,
CASE max_size
WHEN 0 THEN 'Autogrowth is off.'
WHEN -1 THEN 'Autogrowth is on.'
ELSE 'Log file will grow to a maximum size of 2 TB.'
END AutogrowthStatus,
growth AS 'GrowthValue',
'GrowthIncrement' =
CASE
WHEN growth = 0 THEN 'Size is fixed and will not grow.'
WHEN growth > 0 AND is_percent_growth = 0 THEN 'Growth value is in 8-KB pages.'
ELSE 'Growth value is a percentage.' 
END
FROM tempdb.sys.database_files;

-- What is taking space on tempdb
SELECT 
SUM (user_object_reserved_page_count)*8 as user_obj_kb,
SUM (internal_object_reserved_page_count)*8 as internal_obj_kb,
SUM (version_store_reserved_page_count)*8 as version_store_kb,
SUM (unallocated_extent_page_count)*8 as freespace_kb,
SUM (mixed_extent_page_count)*8 as mixedextent_kb
FROM sys.dm_db_file_space_usage

------------------------------------------------------------
--- Script to Check TempDB Speed ---
------------------------------------------------------------ 
--Are writes being evenly distributed between data files?
--Are writes finishing in 20ms or less?
--If the answer is no to either of those questions, we’ve got 
--some performance tuning work to do.
-------------------------------------------------------------


SELECT files.physical_name, files.name, 
stats.num_of_writes, (1.0 * stats.io_stall_write_ms / stats.num_of_writes) AS avg_write_stall_ms,
stats.num_of_reads, (1.0 * stats.io_stall_read_ms / stats.num_of_reads) AS avg_read_stall_ms
FROM sys.dm_io_virtual_file_stats(2, NULL) as stats
INNER JOIN master.sys.master_files AS files 
ON stats.database_id = files.database_id
AND stats.file_id = files.file_id
WHERE files.type_desc = 'ROWS'

--------------------------------
-- Tempdb session File usage --
--------------------------------
SELECT sys.dm_exec_sessions.session_id AS [SESSION ID],
DB_NAME(sys.dm_db_session_space_usage.database_id) AS [DATABASE Name],
HOST_NAME AS [System Name],
program_name AS [Program Name],
login_name AS [USER Name],
status,
cpu_time AS [CPU TIME (in milisec)],
total_scheduled_time AS [Total Scheduled TIME (in milisec)],
total_elapsed_time AS [Elapsed TIME (in milisec)],
(memory_usage * 8) AS [Memory USAGE (in KB)],
(user_objects_alloc_page_count * 8) AS [SPACE Allocated FOR USER Objects (in KB)],
(user_objects_dealloc_page_count * 8) AS [SPACE Deallocated FOR USER Objects (in KB)],
(internal_objects_alloc_page_count * 8) AS [SPACE Allocated FOR Internal Objects (in KB)],
(internal_objects_dealloc_page_count * 8) AS [SPACE Deallocated FOR Internal Objects (in KB)],
CASE is_user_process
WHEN 1 THEN 'user session'
WHEN 0 THEN 'system session'
END AS [SESSION Type], row_count AS [ROW COUNT]
FROM sys.dm_db_session_space_usage INNER join sys.dm_exec_sessions
ON sys.dm_db_session_space_usage.session_id = sys.dm_exec_sessions.session_id