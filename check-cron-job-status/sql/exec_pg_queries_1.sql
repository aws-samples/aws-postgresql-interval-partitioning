CREATE EXTENSION pg_cron;

SELECT cron.schedule('partition maintenance', '*/5 * * * *', $$ call partman.run_maintenance_proc(); $$);

UPDATE cron.job SET database = 'testapg' WHERE jobname = 'partition maintenance';

CREATE USER rds_iamuser;
GRANT CONNECT ON DATABASE postgres TO rds_iamuser;
GRANT rds_iam TO rds_iamuser;

CREATE OR REPLACE FUNCTION get_job_run_details (p_min int) 
RETURNS TABLE (json_agg json) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
	RETURN query 
		SELECT json_agg(j) 
		  FROM (SELECT start_time, end_time, jobid::text, runid::text, database, 
		               command, substring(return_message,1,100) return_message, status 
		          FROM cron.job_run_details
		         WHERE status!='succeeded' 
				   AND end_time >= now() - interval '1 minute' * p_min) j;
END;$$

GRANT USAGE ON SCHEMA cron TO rds_iamuser;
GRANT EXECUTE ON FUNCTION public.get_job_run_details (int) TO rds_iamuser;

