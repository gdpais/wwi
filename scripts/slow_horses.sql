-- Currently executing statements, check total_elapsed_time, cpu_time and wait_time
SELECT 
    req.session_id
    , req.total_elapsed_time AS duration_ms
    , req.cpu_time AS cpu_time_ms
    , req.total_elapsed_time - req.cpu_time AS wait_time
    , req.logical_reads
    , SUBSTRING (REPLACE (REPLACE (SUBSTRING (ST.text, (req.statement_start_offset/2) + 1, 
       ((CASE statement_end_offset
           WHEN -1
           THEN DATALENGTH(ST.text)  
           ELSE req.statement_end_offset
         END - req.statement_start_offset)/2) + 1) , CHAR(10), ' '), CHAR(13), ' '), 
      1, 512)  AS statement_text  
FROM sys.dm_exec_requests AS req
    CROSS APPLY sys.dm_exec_sql_text(req.sql_handle) AS ST
ORDER BY total_elapsed_time DESC;
GO

-- To identify historical long-waiting queries (>20% of the overall elapsed time is wait time)
SELECT t.text,
         qs.total_elapsed_time / qs.execution_count
         AS avg_elapsed_time,
         qs.total_worker_time / qs.execution_count
         AS avg_cpu_time,
         (qs.total_elapsed_time - qs.total_worker_time) / qs.execution_count
         AS avg_wait_time,
         qs.total_logical_reads / qs.execution_count
         AS avg_logical_reads,
         qs.total_logical_writes / qs.execution_count
         AS avg_writes,
         qs.total_elapsed_time
         AS cumulative_elapsed_time
FROM sys.dm_exec_query_stats qs
         CROSS apply sys.Dm_exec_sql_text (sql_handle) t
WHERE (qs.total_elapsed_time - qs.total_worker_time) / qs.total_elapsed_time
         > 0.2
ORDER BY qs.total_elapsed_time / qs.execution_count DESC
GO

-- Currently executing queries with waits longer than 500 ms
SELECT r.session_id, r.wait_type, r.wait_time AS wait_time_ms
FROM sys.dm_exec_requests r 
   JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id 
WHERE wait_time > 500
AND is_user_process = 1
GO

SELECT t.text,
     (qs.total_elapsed_time/1000) / qs.execution_count AS avg_elapsed_time,
     (qs.total_worker_time/1000) / qs.execution_count AS avg_cpu_time,
     ((qs.total_elapsed_time/1000) / qs.execution_count ) - ((qs.total_worker_time/1000) / qs.execution_count) AS avg_wait_time,
     qs.total_logical_reads / qs.execution_count AS avg_logical_reads,
     qs.total_logical_writes / qs.execution_count AS avg_writes,
     (qs.total_elapsed_time/1000) AS cumulative_elapsed_time_all_executions
FROM sys.dm_exec_query_stats qs
     CROSS apply sys.Dm_exec_sql_text (sql_handle) t
WHERE t.text like 'CREATE OR ALTER PROCEDURE sp_import_sales%'
-- Replace <Your Query> with your query or the beginning part of your query. The special chars like '[','_','%','^' in the query should be escaped.
ORDER BY (qs.total_elapsed_time / qs.execution_count) DESC
GO

