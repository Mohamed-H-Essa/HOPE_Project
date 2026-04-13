import json
import boto3
import os
import sys
from decimal import Decimal

sys.path.insert(0, os.path.dirname(__file__))
from assess_logic import assess_session
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
table = dynamodb.Table(os.environ.get('TABLE', 'hope-sessions'))
BUCKET = os.environ.get('HOPE_BUCKET', 'hope-data-placeholder')


def handler(event, context):
    """Ingest endpoint: accepts sensor data from the ESP32 glove.

    The glove sends only its device_id and raw sensor data — it has no
    knowledge of sessions, modes, or exercise names. This handler looks up
    the active session for the device and decides what to do based on the
    session's current status:

      - status == 'assessed'  → exercise phase (uses first item in needed_training)
      - anything else         → assessment phase
    """
    body = json.loads(event.get('body') or '{}')
    device_id = body.get('device_id')
    sensor_data = body.get('data', [])

    if not device_id:
        return respond(400, {'error': 'missing_device_id', 'message': 'device_id is required'})

    if not sensor_data:
        return respond(400, {'error': 'missing_data', 'message': 'sensor data array is required'})

    # Look up the active session for this device (status != 'completed')
    result = table.scan(
        FilterExpression='device_id = :did AND #s <> :done',
        ExpressionAttributeNames={'#s': 'status'},
        ExpressionAttributeValues={
            ':did': device_id,
            ':done': 'completed'
        }
    )

    items = result.get('Items', [])
    if not items:
        return respond(404, {
            'error': 'no_active_session',
            'message': f'No active session linked to device {device_id}. '
                       f'Link the device first via PUT /sessions/{{id}}/device'
        })

    # Pick the most recent active session
    session = sorted(items, key=lambda x: x.get('created_at', ''), reverse=True)[0]
    session_id = session['session_id']

    # Re-fetch with strongly consistent read to get the latest status.
    # The scan above uses eventually consistent reads and may return stale data
    # (e.g., still showing 'questionnaire_done' when the status is already 'assessed').
    fresh = table.get_item(Key={'session_id': session_id}, ConsistentRead=True)
    session = fresh.get('Item', session)
    session_status = session.get('status', '')

    # Route based on session status — the glove never needs to know which phase it is in
    if session_status == 'assessed':
        # Assessment already done: run the exercise phase.
        # Determine exercise name from the session's stored needed_training list.
        ar = session.get('assessment_results', {})
        needed = ar.get('needed_training', [])
        exercise_name = needed[0] if needed else 'Unknown'
        return process_exercise(session_id, sensor_data, exercise_name)
    else:
        # Not yet assessed (created / questionnaire_done / or retry): run assessment.
        return process_assessment(session_id, sensor_data)


def process_assessment(session_id, sensor_data):
    s3_key = f'sensor-data/{session_id}/assess.json'
    s3.put_object(Bucket=BUCKET, Key=s3_key, Body=json.dumps(sensor_data), ContentType='application/json')

    results = assess_session(sensor_data)

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

    return respond(200, {
        'session_id': session_id,
        'assessment_results': results['results'],
        'needed_training': results['needed_training'],
        'features': results['features'],
        'status': 'assessed'
    })


def process_exercise(session_id, sensor_data, exercise_name):
    s3_key = f'sensor-data/{session_id}/exercise.json'
    s3.put_object(Bucket=BUCKET, Key=s3_key, Body=json.dumps({
        'exercise': exercise_name,
        'data': sensor_data
    }), ContentType='application/json')

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

    return respond(200, {
        'session_id': session_id,
        'exercise_results': results,
        'status': 'exercised'
    })


def respond(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(body, cls=_DecimalEncoder)
    }


class _DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, Decimal):
            return float(o)
        return super().default(o)
