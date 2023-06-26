#!/usr/bin/env python3
#
# /usr/local/bin/secrets.py --aws_region eu-west-1 --secret_list deployer_aws,gitlab-access-token
#
import json
import boto3
import base64
from botocore.exceptions import ClientError
import argparse


def get_secret(secret_name, region_name):
    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'DecryptionFailureException':
            raise e
        elif e.response['Error']['Code'] == 'InternalServiceErrorException':
            raise e
        elif e.response['Error']['Code'] == 'InvalidParameterException':
            raise e
        elif e.response['Error']['Code'] == 'InvalidRequestException':
            raise e
        elif e.response['Error']['Code'] == 'ResourceNotFoundException':
            raise e
    else:
        if 'SecretString' in get_secret_value_response:
            secret = get_secret_value_response['SecretString']
            return json.loads(secret)
        else:
            decoded_binary_secret = base64.b64decode(get_secret_value_response['SecretBinary'])
            return decoded_binary_secret


parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('--secret_list', required=True, help='')
parser.add_argument('--aws_region', required=True, help='')
args = parser.parse_args()

output = ''
for secret_name in args.secret_list.split(','):
    credentials = get_secret(secret_name, args.aws_region)
    for k, v in credentials.items():
        output += '%s=%s ' % (k, v)

print(output)