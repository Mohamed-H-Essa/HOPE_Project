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


_REQUIRED_SAMPLE_KEYS = (
    'time', 'flex1', 'flex2', 'fsr1', 'fsr2', 'emg',
    'ax', 'ay', 'az', 'gx', 'gy', 'gz',
)


def _validate_payload(device_id, sensor_data):
    """Lightweight shape check. Both ends are well-behaved so this only catches
    obviously malformed payloads (string instead of number, missing keys) that
    would otherwise crash assess_logic with a confusing 502."""
    if not isinstance(sensor_data, list):
        return 'sensor data must be a list of samples'
    if not sensor_data:
        return 'sensor data array is required'
    sample = sensor_data[0]
    if not isinstance(sample, dict):
        return 'each sample must be an object'
    missing = [k for k in _REQUIRED_SAMPLE_KEYS if k not in sample]
    if missing:
        return f'sample missing required keys: {missing}'
    for k in _REQUIRED_SAMPLE_KEYS:
        v = sample[k]
        if not isinstance(v, (int, float)) or isinstance(v, bool):
            return f'sample[{k!r}] must be a number, got {type(v).__name__}'
    return None


def handler(event, context):
    """Ingest endpoint: accepts sensor data from the ESP32 glove.

    The glove sends only its device_id and raw sensor data — it has no
    knowledge of sessions, modes, or exercise names. This handler looks up
    the active session for the device and routes by DATA PRESENCE, not by
    status string:

      - assessment_results absent → assessment phase (stores results)
      - assessment_results present → exercise phase (uses first item in
                                     needed_training as the exercise name)

    Routing by data presence rather than `status` avoids a race: the patient
    can submit the post-assessment questionnaire between batches, which
    otherwise would overwrite the lifecycle marker.
    """
    raw = event.get('body') or ''
    try:
        body = json.loads(raw) if raw.strip() else {}
    except (ValueError, TypeError):
        return respond(400, {'error': 'invalid_json', 'message': 'Request body must be valid JSON'})

    device_id = body.get('device_id')
    sensor_data = body.get('data', [])

    if not device_id:
        return respond(400, {'error': 'missing_device_id', 'message': 'device_id is required'})

    err = _validate_payload(device_id, sensor_data)
    if err:
        return respond(400, {'error': 'invalid_payload', 'message': err})

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

    # Route by DATA presence, not by the status string. Status can be overwritten
    # by PUT /questionnaire to 'questionnaire_done' in between the assessment and
    # exercise ingest batches; if we routed on status we'd mistake the exercise
    # batch for a retry-assessment and overwrite assessment_results. Using the
    # presence of assessment_results is the canonical invariant: if assessment
    # results exist, the glove is posting exercise data. The glove itself has
    # no knowledge of phase.
    ar = session.get('assessment_results')
    if ar:
        needed = ar.get('needed_training', []) if isinstance(ar, dict) else []
        exercise_name = needed[0] if needed else 'Unknown'
        return process_exercise(session_id, sensor_data, exercise_name)
    else:
        return process_assessment(session_id, sensor_data)


def process_assessment(session_id, sensor_data):
    s3_key = f'sensor-data/{session_id}/assess.json'
    s3.put_object(Bucket=BUCKET, Key=s3_key, Body=json.dumps(sensor_data), ContentType='application/json')

    results = assess_session(sensor_data)

    # Persisted shape matches GET /sessions/{id} so clients only need to
    # understand one schema. assessment_results merges PASS/FAIL strings with
    # the needed_training list; features are stored as strings (DynamoDB
    # number→Decimal coercion is fine, but we stringify for consistency with
    # how the rest of the surface treats them).
    assessment_results = {k: ('PASS' if v else 'FAIL') for k, v in results['results'].items()}
    assessment_results['needed_training'] = results['needed_training']
    assessment_features = {k: str(v) for k, v in results['features'].items()}

    table.update_item(
        Key={'session_id': session_id},
        UpdateExpression='SET assessment_results = :ar, assessment_features = :af, sensor_data_assess_s3 = :s3, #st = :status',
        ExpressionAttributeNames={'#st': 'status'},
        ExpressionAttributeValues={
            ':ar': assessment_results,
            ':af': assessment_features,
            ':s3': s3_key,
            ':status': 'assessed'
        }
    )

    return respond(200, {
        'session_id': session_id,
        'assessment_results': assessment_results,
        'assessment_features': assessment_features,
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
