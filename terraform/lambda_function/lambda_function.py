import json
import boto3
import os

ssm = boto3.client('ssm')

def lambda_handler(event, context):
    # Fetch the parameter name from environment variable
    parameter_name = os.environ['SSM_PARAMETER_NAME']
    
    try:
        # Retrieve the parameter value from SSM Parameter Store
        response = ssm.get_parameter(
            Name=parameter_name,
            WithDecryption=True  # Decrypt if it is a SecureString
        )
        
        parameter_value = response['Parameter']['Value']
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Parameter retrieved successfully!',
                'parameter_value': parameter_value
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
