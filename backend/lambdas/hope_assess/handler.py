import json
import boto3
import os
import sys

# Allow importing assess_logic from the same directory
sys.path.insert(0, os.path.dirname(__file__))
from assess_logic import assess_session

dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')
table = dynamodb.Table('hope-sessions')
BUCKET = os.environ.get('HOPE_BUCKET', 'hope-data-placeholder')


def handler(event, context):
    session_id = event['pathParameters']['session_id']
    data = json.loads(event['body'])

    s3_key = f'sensor-data/{session_id}/assess.json'
    s3.put_object(Bucket=BUCKET, Key=s3_key, Body=json.dumps(data), ContentType='application/json')

    results = assess_session(data)

    table.update_item(
        Key={'session_id': session_id},
        UpdateExpression='SET assessment_results = :ar, assessment_features = :af, sensor_data_assess_s3 = :s3, #st = :status',
        ExpressionAttributeNames={'#st': 'status'},
        ExpressionAttributeValues={
            ':ar': {k: ('PASS' if v else 'FAIL') for k, v in results['results'].items()} | {'needed_training': results['needed_training']},
            ':af': {k: str(v) for k, v in results['features'].items()},
            ':s3': s3_key,
            ':status': 'assessed'
        }
    )

    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
        'body': json.dumps({
            'session_id': session_id,
            'assessment_results': results['results'],
            'needed_training': results['needed_training'],
            'features': results['features'],
            'status': 'assessed'
        })
    }
