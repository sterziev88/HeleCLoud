import boto3
import csv
import pymysql

s3_client = boto3.client('s3')
 
#RDS config
rds_host  = "terraform-20220213132052827000000001.cygwnlvunytv.eu-central-1.rds.amazonaws.com"
name = "sterzievdb"
password = "sterzievdb"
db_name = "testdb"

#Get csv objrct from S3
def lambda_handler(event, context):
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    
    response = s3_client.get_object(Bucket=bucket_name,Key=key)
    contents = response["Body"].read().decode("utf-8").split()
    results = []
    for row in csv.DictReader(contents):
        results.append(row.values())
    print(results)
    #Connection to RDS
    conn = pymysql.connect(host=rds_host, user=name, passwd=password, db=db_name)
    mycursor = conn.cursor()
	#Create a new table
    mycursor.execute("CREATE TABLE customers (number VARCHAR(255), name VARCHAR(255), year_of_birth VARCHAR(255))")
	#Insert new values in the table
    sql = "INSERT INTO customers (number, name, year_of_birth)   VALUES (%s,%s,%s)"
    mycursor = conn.cursor()
    mycursor.execute(sql,results)
    conn.commit()
    print(mycursor.rowcount, "record inserted.")