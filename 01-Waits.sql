
-- Waits
--#####################################################################################################################
-- Query 1 : This queries the sys.dm_os_waiting_tasks DMV to show all waiting tasks currently active or blocked, 
-- revealing the wait type, duration, and resource
SELECT blocking.session_id AS blocking_session_id , 
blocked.session_id AS blocked_session_id , 
waitstats.wait_type AS blocking_resource , 
waitstats.wait_duration_ms , 
waitstats.resource_description , 
blocked_cache.text AS blocked_text , 
blocking_cache.text AS blocking_text 
FROM sys.dm_exec_connections AS blocking 
INNER JOIN sys.dm_exec_requests blocked ON blocking.session_id = blocked.blocking_session_id 
CROSS APPLY sys.dm_exec_sql_text(blocked.sql_handle) blocked_cache 
CROSS APPLY sys.dm_exec_sql_text(blocking.most_recent_sql_handle) blocking_cache 
INNER JOIN sys.dm_os_waiting_tasks waitstats ON waitstats.session_id = blocked.session_id

--#####################################################################################################################
-- Query 2: Determine if CPU is under pressure
-- The sys.dm_os_wait_stats DMV shows aggregated wait times and counts starting from when the wait statistics were cleared, or from when the server starte
SELECT SUM(signal_wait_time_ms) AS TotalSignalWaitTime , 
( SUM(CAST(signal_wait_time_ms AS NUMERIC(20, 2))) / SUM(CAST(wait_time_ms AS NUMERIC(20, 2))) * 100 ) AS PercentageSignalWaitsOfTotalTime 
FROM sys.dm_os_wait_stats

-- Clear the wait stats data manually.
DBCC SQLPERF ('sys.dm_os_wait_stats', CLEAR)

--#####################################################################################################################
-- Query 3: This DMV returns one row for each of the SQL Server schedulers and it lists the total number of tasks 
-- that are assigned to each scheduler, as well as the number that are runnable. 
-- below 255 is system processes like backcup, etc.
SELECT scheduler_id , 
current_tasks_count , 
runnable_tasks_count 
FROM sys.dm_os_schedulers 
WHERE scheduler_id < 255

--#####################################################################################################################
-- Query 4: primary resource waits
WITH [Waits] AS
(SELECT
[wait_type],
[wait_time_ms] / 1000.0 AS [Wait Time (sec)],
([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [Resource (sec)],
[signal_wait_time_ms] / 1000.0 AS [Signal (sec)],
[waiting_tasks_count] AS [WaitCount],
100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER() AS [Percentage],
ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]
FROM sys.dm_os_wait_stats
WHERE [wait_type] NOT IN (
N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR',
N'BROKER_TASK_STOP', N'BROKER_TO_FLUSH',
N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE',
N'CHKPT', N'CLR_AUTO_EVENT',
N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE',
N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE',
N'DBMIRROR_WORKER_QUEUE', N'DBMIRRORING_CMD',
N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',
N'EXECSYNC', N'FSAGENT',
N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSHC_MUTEX',
N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
N'HADR_LOGCAPTURE_WAIT', N'HADR_NOTIFICATION_DEQUEUE',
N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE',
N'KSOURCE_WAKEUP', N'LAZYWRITER_SLEEP',
N'LOGMGR_QUEUE', N'ONDEMAND_TASK_QUEUE',
N'PWAIT_ALL_COMPONENTS_INITIALIZED',
N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
N'REQUEST_FOR_DEADLOCK_SEARCH', N'RESOURCE_QUEUE',
N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH',
N'SLEEP_DBSTARTUP', N'SLEEP_DCOMSTARTUP',
N'SLEEP_MASTERDBREADY', N'SLEEP_MASTERMDREADY',
N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP',
N'SLEEP_SYSTEMTASK', N'SLEEP_TASK',
N'SLEEP_TEMPDBSTARTUP', N'SNI_HTTP_ACCEPT',
N'SP_SERVER_DIAGNOSTICS_SLEEP', N'SQLTRACE_BUFFER_FLUSH',
N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
N'SQLTRACE_WAIT_ENTRIES', N'WAIT_FOR_RESULTS',
N'WAITFOR', N'WAITFOR_TASKSHUTDOWN',
N'WAIT_XTP_HOST_WAIT', N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
N'WAIT_XTP_CKPT_CLOSE', N'XE_DISPATCHER_JOIN',
N'XE_DISPATCHER_WAIT', N'XE_TIMER_EVENT')
)
SELECT
[W1].[wait_type] AS [WaitType],
[W1].[Wait Time (sec)],
[W1].[Resource (sec)],
[W1].[Signal (sec)],
[W1].[WaitCount],
[W1].[Percentage],
[W1].[Wait Time (sec)] / [W1].[WaitCount] as [Mean Wait Time (sec)],
[W1].[Resource (sec)] / [W1].[WaitCount] as [Mean Resource Wait (sec)],
[W1].[Signal (sec)] / [W1].[WaitCount] as [Mean Signal Wait (sec)]
FROM [Waits] AS [W1]
INNER JOIN [Waits] AS [W2]
ON [W2].[RowNum] <= [W1].[RowNum]
GROUP BY [W1].[RowNum], [W1].[wait_type], [W1].[Wait Time (sec)],
[W1].[Resource (sec)], [W1].[Signal (sec)], [W1].[WaitCount], [W1].[Percentage]
HAVING SUM ([W2].[Percentage]) - [W1].[Percentage] < 95; -- percentage threshold

--#####################################################################################################################
-- Query 5: IO waits details (which database / datafiles get mist read / writes).
SELECT DB_NAME(vfs.database_id) AS database_name , 
vfs.database_id , 
vfs.file_id , 
io_stall_read_ms / NULLIF(num_of_reads, 0) AS avg_read_latency , 
io_stall_write_ms / NULLIF(num_of_writes, 0) AS avg_write_latency , 
io_stall_write_ms / NULLIF(num_of_writes + num_of_writes, 0) AS avg_total_latency , 
num_of_bytes_read / NULLIF(num_of_reads, 0) AS avg_bytes_per_read , 
num_of_bytes_written / NULLIF(num_of_writes, 0) AS avg_bytes_per_write , 
vfs.io_stall , 
vfs.num_of_reads , 
vfs.num_of_bytes_read , 
vfs.io_stall_read_ms , 
vfs.num_of_writes , 
vfs.num_of_bytes_written , 
vfs.io_stall_write_ms , 
size_on_disk_bytes / 1024 / 1024. AS size_on_disk_mbytes , 
physical_name 
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs 
JOIN sys.master_files AS mf ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
ORDER BY avg_total_latency DESC

