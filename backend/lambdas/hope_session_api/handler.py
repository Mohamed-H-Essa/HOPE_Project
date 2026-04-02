import json
import boto3
import uuid
import os
from datetime import datetime, timezone
from decimal import Decimal


class _DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, Decimal):
            return float(o)
        return super().default(o)

dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')
table = dynamodb.Table('hope-sessions')
BUCKET = os.environ.get('HOPE_BUCKET', 'hope-data-placeholder')


def handler(event, context):
    method = event['httpMethod']
    path = event['resource']
    path_params = event.get('pathParameters') or {}
    body = json.loads(event.get('body') or '{}')

    if method == 'POST' and path == '/sessions':
        return create_session()

    elif method == 'PUT' and path == '/sessions/{session_id}/questionnaire':
        return save_questionnaire(path_params['session_id'], body)

    elif method == 'POST' and path == '/sessions/{session_id}/video-upload-url':
        return get_video_upload_url(path_params['session_id'])

    elif method == 'PUT' and path == '/sessions/{session_id}/device':
        return link_device(path_params['session_id'], body)

    elif method == 'GET' and path == '/sessions':
        return list_sessions()

    elif method == 'GET' and path == '/sessions/{session_id}':
        return get_session(path_params['session_id'])

    return respond(404, {'error': 'not_found'})


def create_session():
    session_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()
    table.put_item(Item={
        'session_id': session_id,
        'created_at': now,
        'status': 'created'
    })
    return respond(201, {'session_id': session_id, 'created_at': now, 'status': 'created'})


def save_questionnaire(session_id, body):
    table.update_item(
        Key={'session_id': session_id},
        UpdateExpression='SET questionnaire = :q, #s = :s',
        ExpressionAttributeNames={'#s': 'status'},
        ExpressionAttributeValues={':q': body.get('answers', body), ':s': 'questionnaire_done'}
    )
    return respond(200, {'status': 'questionnaire_done'})


def get_video_upload_url(session_id):
    key = f'videos/{session_id}/video.mp4'
    url = s3.generate_presigned_url(
        'put_object',
        Params={'Bucket': BUCKET, 'Key': key, 'ContentType': 'video/mp4'},
        ExpiresIn=600
    )
    table.update_item(
        Key={'session_id': session_id},
        UpdateExpression='SET video_s3_key = :k',
        ExpressionAttributeValues={':k': key}
    )
    return respond(200, {'upload_url': url, 's3_key': key, 'expires_in': 600})


def link_device(session_id, body):
    """Link a device to this session for the /ingest endpoint."""
    device_id = body.get('device_id')
    if not device_id:
        return respond(400, {'error': 'missing_device_id', 'message': 'device_id is required'})

    table.update_item(
        Key={'session_id': session_id},
        UpdateExpression='SET device_id = :d',
        ExpressionAttributeValues={':d': device_id}
    )
    return respond(200, {'status': 'device_linked', 'device_id': device_id})


def list_sessions():
    result = table.scan()
    sessions = sorted(result.get('Items', []), key=lambda x: x.get('created_at', ''), reverse=True)
    summaries = []
    for s in sessions:
        ar = s.get('assessment_results', {})
        er = s.get('exercise_results', {})
        passed = sum(1 for v in ar.values() if v == 'PASS' and isinstance(v, str))
        total = len([k for k in ar if k not in ('needed_training', 'features')])
        summaries.append({
            'session_id': s['session_id'],
            'created_at': s['created_at'],
            'status': s.get('status', 'created'),
            'assessment_summary': {
                'passed': passed,
                'total': total,
                'needed_training': ar.get('needed_training', [])
            },
            'exercise_overall_percent': er.get('overall_percent') if er else None
        })
    return respond(200, {'sessions': summaries})


def get_session(session_id):
    result = table.get_item(Key={'session_id': session_id})
    item = result.get('Item')
    if not item:
        return respond(404, {'error': 'session_not_found', 'message': f'No session with id {session_id}'})

    video_url = None
    if item.get('video_s3_key'):
        video_url = s3.generate_presigned_url(
            'get_object',
            Params={'Bucket': BUCKET, 'Key': item['video_s3_key']},
            ExpiresIn=3600
        )

    return respond(200, {
        'session_id': item['session_id'],
        'created_at': item['created_at'],
        'status': item.get('status', 'created'),
        'device_id': item.get('device_id'),
        'questionnaire': item.get('questionnaire'),
        'assessment_results': item.get('assessment_results'),
        'assessment_features': item.get('assessment_features'),
        'exercise_results': item.get('exercise_results'),
        'video_url': video_url
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
