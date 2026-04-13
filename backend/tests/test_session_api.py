"""Level 2 tests — hope_session_api handler (mocked AWS)."""
import json
import os
import sys
import importlib.util
import pytest
import boto3
from moto import mock_aws

HANDLER_PATH = os.path.join(os.path.dirname(__file__), '../lambdas/hope_session_api/handler.py')
TABLE_NAME = 'hope-sessions'
BUCKET_NAME = 'hope-data-test'


def set_aws_env():
    os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'
    os.environ['AWS_ACCESS_KEY_ID'] = 'test'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'test'
    os.environ['HOPE_BUCKET'] = BUCKET_NAME


def load_handler():
    spec = importlib.util.spec_from_file_location('hope_session_api_handler', HANDLER_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def aws_setup():
    with mock_aws():
        set_aws_env()
        ddb = boto3.resource('dynamodb', region_name='us-east-1')
        ddb.create_table(
            TableName=TABLE_NAME,
            KeySchema=[{'AttributeName': 'session_id', 'KeyType': 'HASH'}],
            AttributeDefinitions=[{'AttributeName': 'session_id', 'AttributeType': 'S'}],
            BillingMode='PAY_PER_REQUEST'
        )
        s3 = boto3.client('s3', region_name='us-east-1')
        s3.create_bucket(Bucket=BUCKET_NAME)
        yield load_handler()


def apigw_event(method, resource, path_params=None, body=None):
    return {
        'httpMethod': method,
        'resource': resource,
        'pathParameters': path_params or {},
        'body': json.dumps(body) if body is not None else None
    }


class TestCreateSession:
    def test_post_sessions_returns_201(self, aws_setup):
        resp = aws_setup.handler(apigw_event('POST', '/sessions'), None)
        assert resp['statusCode'] == 201

    def test_post_sessions_returns_session_id(self, aws_setup):
        resp = aws_setup.handler(apigw_event('POST', '/sessions'), None)
        body = json.loads(resp['body'])
        assert 'session_id' in body
        assert len(body['session_id']) > 0

    def test_post_sessions_returns_created_at(self, aws_setup):
        resp = aws_setup.handler(apigw_event('POST', '/sessions'), None)
        body = json.loads(resp['body'])
        assert 'created_at' in body

    def test_post_sessions_status_is_created(self, aws_setup):
        resp = aws_setup.handler(apigw_event('POST', '/sessions'), None)
        body = json.loads(resp['body'])
        assert body['status'] == 'created'

    def test_cors_header_present(self, aws_setup):
        resp = aws_setup.handler(apigw_event('POST', '/sessions'), None)
        assert resp['headers']['Access-Control-Allow-Origin'] == '*'


class TestGetSession:
    def test_get_existing_session_returns_200(self, aws_setup):
        create_resp = aws_setup.handler(apigw_event('POST', '/sessions'), None)
        session_id = json.loads(create_resp['body'])['session_id']

        resp = aws_setup.handler(apigw_event('GET', '/sessions/{session_id}',
                                             path_params={'session_id': session_id}), None)
        assert resp['statusCode'] == 200

    def test_get_session_returns_correct_id(self, aws_setup):
        create_resp = aws_setup.handler(apigw_event('POST', '/sessions'), None)
        session_id = json.loads(create_resp['body'])['session_id']

        resp = aws_setup.handler(apigw_event('GET', '/sessions/{session_id}',
                                             path_params={'session_id': session_id}), None)
        body = json.loads(resp['body'])
        assert body['session_id'] == session_id

    def test_get_missing_session_returns_404(self, aws_setup):
        resp = aws_setup.handler(apigw_event('GET', '/sessions/{session_id}',
                                             path_params={'session_id': 'nonexistent-id'}), None)
        assert resp['statusCode'] == 404

    def test_get_missing_session_error_body(self, aws_setup):
        resp = aws_setup.handler(apigw_event('GET', '/sessions/{session_id}',
                                             path_params={'session_id': 'nonexistent-id'}), None)
        body = json.loads(resp['body'])
        assert 'error' in body


class TestListSessions:
    def test_get_sessions_returns_200(self, aws_setup):
        resp = aws_setup.handler(apigw_event('GET', '/sessions'), None)
        assert resp['statusCode'] == 200

    def test_get_sessions_returns_list(self, aws_setup):
        resp = aws_setup.handler(apigw_event('GET', '/sessions'), None)
        body = json.loads(resp['body'])
        assert 'sessions' in body
        assert isinstance(body['sessions'], list)

    def test_get_sessions_includes_created_sessions(self, aws_setup):
        aws_setup.handler(apigw_event('POST', '/sessions'), None)
        aws_setup.handler(apigw_event('POST', '/sessions'), None)

        resp = aws_setup.handler(apigw_event('GET', '/sessions'), None)
        body = json.loads(resp['body'])
        assert len(body['sessions']) == 2


class TestQuestionnaire:
    def test_put_questionnaire_returns_200(self, aws_setup):
        create_resp = aws_setup.handler(apigw_event('POST', '/sessions'), None)
        session_id = json.loads(create_resp['body'])['session_id']

        resp = aws_setup.handler(apigw_event(
            'PUT', '/sessions/{session_id}/questionnaire',
            path_params={'session_id': session_id},
            body={'answers': {'pain_level': 3, 'stiffness': True}}
        ), None)
        assert resp['statusCode'] == 200

    def test_put_questionnaire_status_becomes_questionnaire_done(self, aws_setup):
        create_resp = aws_setup.handler(apigw_event('POST', '/sessions'), None)
        session_id = json.loads(create_resp['body'])['session_id']

        aws_setup.handler(apigw_event(
            'PUT', '/sessions/{session_id}/questionnaire',
            path_params={'session_id': session_id},
            body={'answers': {'pain_level': 3}}
        ), None)

        get_resp = aws_setup.handler(apigw_event('GET', '/sessions/{session_id}',
                                                 path_params={'session_id': session_id}), None)
        body = json.loads(get_resp['body'])
        assert body['status'] == 'questionnaire_done'

    def test_put_questionnaire_accepts_raw_shape_from_app(self, aws_setup):
        # The Flutter app sends the 4 answer fields at the top level, not
        # wrapped in {"answers": ...}. The backend supports both shapes via
        # `body.get('answers', body)` — this test pins the raw shape.
        create_resp = aws_setup.handler(apigw_event('POST', '/sessions'), None)
        session_id = json.loads(create_resp['body'])['session_id']

        raw_body = {
            'pain_level': 5,
            'stiffness': False,
            'comments': 'Feeling okay today',
            'goal': 'improve_grip',
        }
        resp = aws_setup.handler(apigw_event(
            'PUT', '/sessions/{session_id}/questionnaire',
            path_params={'session_id': session_id},
            body=raw_body,
        ), None)
        assert resp['statusCode'] == 200

        get_resp = aws_setup.handler(apigw_event('GET', '/sessions/{session_id}',
                                                 path_params={'session_id': session_id}), None)
        got = json.loads(get_resp['body'])
        assert got['status'] == 'questionnaire_done'
        assert got['questionnaire'] == raw_body


class TestVideoUploadUrl:
    def test_post_video_upload_url_returns_200(self, aws_setup):
        create_resp = aws_setup.handler(apigw_event('POST', '/sessions'), None)
        session_id = json.loads(create_resp['body'])['session_id']

        resp = aws_setup.handler(apigw_event(
            'POST', '/sessions/{session_id}/video-upload-url',
            path_params={'session_id': session_id}
        ), None)
        assert resp['statusCode'] == 200

    def test_post_video_upload_url_returns_upload_url(self, aws_setup):
        create_resp = aws_setup.handler(apigw_event('POST', '/sessions'), None)
        session_id = json.loads(create_resp['body'])['session_id']

        resp = aws_setup.handler(apigw_event(
            'POST', '/sessions/{session_id}/video-upload-url',
            path_params={'session_id': session_id}
        ), None)
        body = json.loads(resp['body'])
        assert 'upload_url' in body
        assert len(body['upload_url']) > 0


class TestUnknownRoute:
    def test_unknown_route_returns_404(self, aws_setup):
        resp = aws_setup.handler(apigw_event('DELETE', '/sessions'), None)
        assert resp['statusCode'] == 404
