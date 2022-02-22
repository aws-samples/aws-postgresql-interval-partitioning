CREATE EXTENSION pg_cron;

SELECT cron.schedule('partition maintenance', '*/5 * * * *', $$ call partman.run_maintenance_proc(); $$);

UPDATE cron.job SET database = 'testapg' WHERE jobname = 'partition maintenance';

CREATE USER rds_iamuser;
GRANT CONNECT ON DATABASE postgres TO rds_iamuser;
GRANT rds_iam TO rds_iamuser;

CREATE POLICY cron_job_run_details_view_policy
ON cron.job_run_details
AS PERMISSIVE
FOR SELECT
TO rds_iamuser
USING (true);

GRANT USAGE ON SCHEMA cron TO rds_iamuser;
GRANT SELECT ON cron.job_run_details TO rds_iamuser;

