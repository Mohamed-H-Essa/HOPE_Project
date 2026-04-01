import json
import boto3
import os
import sys
from decimal import Decimal

sys.path.insert(0, os.path.dirname(__file__))
from exercise_logic import run_exercise


def floats_to_decimal(obj):
    """Recursively convert floats to Decimal for DynamoDB storage."""
    if isinstance(obj, float):
        return Decimal(str(obj))
    elif isinstance(obj, dict):
        return {k: floats_to_decimal(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [floats_to_decimal(i) for i in obj]
    return obj

dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')
table = dynamodb.Table('hope-sessions')
BUCKET = os.environ.get('HOPE_BUCKET', 'hope-data-placeholder')


def handler(event, context):
    session_id = event['pathParameters']['session_id']
    body = json.loads(event['body'])
    sensor_data = body.get('data', [])
    exercise_name = body.get('exercise', 'Unknown')

    s3_key = f'sensor-data/{session_id}/exercise.json'
    s3.put_object(Bucket=BUCKET, Key=s3_key, Body=json.dumps(body), ContentType='application/json')

    results = run_exercise(sensor_data, exercise_name)

    table.update_item(
        Key={'session_id': session_id},
        UpdateExpression='SET exercise_results = :er, sensor_data_exercise_s3 = :s3, #st = :status',
        ExpressionAttributeNames={'#st': 'status'},
        ExpressionAttributeValues={
            ':er': floats_to_decimal(results),
            ':s3': s3_key,
            ':status': 'exercised'
        }
    )

    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
        'body': json.dumps({'session_id': session_id, 'exercise_results': results, 'status': 'exercised'})
    }
