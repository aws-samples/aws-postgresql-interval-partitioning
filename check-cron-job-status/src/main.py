import os
import ssl
import boto3
import pg8000
import datetime as dt



v_ssm = boto3.client('ssm',os.environ['AWS_REGION'])
v_sns = boto3.client('sns')
v_rds = boto3.client("rds")
context = ssl.create_default_context(cafile="rds-ca-2019-root.pem")

v_db_name = 'postgres'
v_db_user = 'rds_iamuser'

def check_cron_job_status(event, context):
    v_error = False
    v_message = ''

    for val in event.values():
        v_ssm_param_path = val
        v_response = v_ssm.get_parameters_by_path(Path=v_ssm_param_path, Recursive=True)
        v_param_list = v_response['Parameters']

        for v_param in v_param_list:
            v_param_name=v_param['Name'].split("/")[-1]
            v_param_value=v_param['Value']
            
            if v_param_name == 'db_host':
                v_db_host = v_param_value
            elif v_param_name == 'db_port':
                v_db_port = v_param_value
            elif v_param_name == 'cron_hist_in_minutes':
                v_cron_hist_in_minutes = v_param_value
            elif v_param_name == 'sns_topic':
                v_sns_topic = v_param_value
            
        print(dt.datetime.now(), " :",
              "Connect to database = {}, on host = {}, on port = {}, using username = {} and checking cron history from last {} minutes".format(
                  v_db_name, v_db_host, v_db_port, v_db_user, v_cron_hist_in_minutes))
                  
        v_db_pass = v_rds.generate_db_auth_token(DBHostname=v_db_host, Port=v_db_port, DBUsername=v_db_user)
        conn = pg8000.connect(host=v_db_host, database=v_db_name, port=v_db_port, user=v_db_user, password=v_db_pass, ssl_context=True)


        query = "select json_agg(j) from (select start_time, end_time, jobid::text, runid::text, database, " \
                "command, substring(return_message,1,100) return_message, status from  cron.job_run_details " \
                "where status!='succeeded' and end_time >= now() - interval '" + str(v_cron_hist_in_minutes) + " minute') j"
    
        print(dt.datetime.now(), " : Executing Query : ", query)
    
        cursor = conn.cursor()
        query = cursor.execute(query)
        rows = cursor.fetchall()
        
        if (rows[0][0]) != None:
            for row in rows[0][0]:
                v_message = v_message + 'Job Start time = ' + row['start_time'] + ', End Time = ' + row['end_time'] + \
                            ', with command = ' + row['command'] + '" , Job ID = ' + row['jobid'] + ' and Run ID = ' + \
                            row['runid'] + ' has failed with ERROR !!! = ' + row['return_message'] + "\n"
    
            print(v_message)
            response = v_sns.publish(TopicArn=v_sns_topic, Message=v_message, Subject="Cron Job Errors!!! for DB Cluster = " + v_db_host.split('.')[0])

        v_message = ''
        cursor.close()
        conn.commit()
        conn.close()

    
    print(dt.datetime.now(), " :", "Execution Successful")

    return 'Execution Successful'


