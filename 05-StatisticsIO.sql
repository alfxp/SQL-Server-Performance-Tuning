-----------------------
--- Statistics IO --
-----------------------

DROP TABLE ScanCount
GO

CREATE TABLE ScanCount (Id INT IDENTITY(1,1),
Value CHAR(1))
GO


INSERT INTO ScanCount (Value ) VALUES ('A') ,('B'),('C'),('D'), ('E') , ('F') 
GO

CREATE UNIQUE CLUSTERED INDEX ix_ScanCount ON ScanCount(Id)
GO

SET STATISTICS IO ON

--Unique clustered Index used to search single value
SELECT * FROM ScanCount WHERE Id =1
--Unique clustered Index used to search multiple value
SELECT * FROM ScanCount WHERE Id IN(1,2,3,4,5,6)
--Unique clustered Index used to search multiple value
SELECT * FROM ScanCount WHERE Id BETWEEN 1 AND 6

--Scan count is 0 if the index used is a unique index or clustered index on a primary key and you are seeking for only one value. For example WHERE Primary_Key_Column = <value>.
--Scant count is 1 when you are searching for one value using a non-unique clustered index which is defined on a non-primary key column. This is done to check for duplicate values for the key value that you are searching for. For example WHERE Clustered_Index_Key_Column = <value>.
--Scan count is N when N is the number of different seek/scan started towards the left or right side at the leaf level after locating a key value using the index key.

DBCC MEMORYSTATUS

SELECT *
FROM sys.dm_os_memory_clerks


SELECT *
FROM sys.dm_os_memory_cache_clock_hands
WHERE rounds_count > 0

--sys.dm_os_memory_brokers provides information about memory allocations using the internal SQL Server memory manager. The information provided can be useful in determining very large memory consumers. 
--•sys.dm_os_memory_nodes and sys.dm_os_memory_node_access_stats provide summary information of the memory allocations per memory node and node access statistics grouped by the type of the page. This information can be used instead of running DBCC MEMORYSTATUS to quickly obtain summary memory usage. (sys.dm_os_memory_node_access_stats is populated under dynamic trace flag 842 due to its performance impact.) 
--•sys.dm_os_nodes provides information about CPU node configuration for SQL Server. This DMV also reflects software NUMA (soft-NUMA) configuration. 
--•sys.dm_os_sys_memory returns the system memory information. The ‘Available physical memory is low' value in the system_memory_state_desc column is a sign of external memory pressure that requires further analysis.

--SQL Server ring buffers

SELECT ring_buffer_type, COUNT(*) AS [Events]
FROM sys.dm_os_ring_buffers
GROUP BY ring_buffer_type
ORDER BY ring_buffer_type

--RING_BUFFER_SCHEDULER_MONITOR: Stores information about the overall state of the server. The SystemHealth records are created with one minute intervals. 
--•RING_BUFFER_RESOURCE_MONITOR: This ring buffer captures every memory state change by using resource monitor notifications. 
--•RING_BUFFER_OOM: This ring buffer contains records indicating out-of-memory conditions. 
--•RING_BUFFER_MEMORY_BROKER: This ring buffer contains memory notifications for the Resource Governor resource pool. 
--•RING_BUFFER_BUFFER_POOL: This ring buffer contains records of buffer pool failures.

