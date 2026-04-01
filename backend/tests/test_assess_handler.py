"""Level 2 tests — hope_assess handler (mocked AWS)."""
import json
import math
import os
import sys
import importlib.util
import pytest
import boto3
from moto import mock_aws

HANDLER_PATH = os.path.join(os.path.dirname(__file__), '../lambdas/hope_assess/handler.py')
TABLE_NAME = 'hope-sessions'
BUCKET_NAME = 'hope-data-test'


def set_aws_env():
    os.environ['AWS_DEFAULT_REGION'] = 'eu-west-3'
    os.environ['AWS_ACCESS_KEY_ID'] = 'test'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'test'
    os.environ['HOPE_BUCKET'] = BUCKET_NAME


def load_handler():
    spec = importlib.util.spec_from_file_location('hope_assess_handler', HANDLER_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def make_sample(i, flex1=60, flex2=60, fsr1=70, fsr2=70):
    return {
        "time": i * 50,
        "ax": 1.5 + 0.5 * math.sin(i * 0.3),
        "ay": 0.2 + 0.1 * math.cos(i * 0.3),
        "az": 0.2, "gx": 70.0, "gy": 0, "gz": 0,
        "flex1": flex1, "flex2": flex2, "fsr1": fsr1, "fsr2": fsr2, "emg": 50
    }


def good_sensor_data():
    return [make_sample(i) for i in range(20)]


@pytest.fixture
def aws_setup():
    with mock_aws():
        set_aws_env()
        ddb = boto3.resource('dynamodb', region_name='eu-west-3')
        table = ddb.create_table(
            TableName=TABLE_NAME,
            KeySchema=[{'AttributeName': 'session_id', 'KeyType': 'HASH'}],
            AttributeDefinitions=[{'AttributeName': 'session_id', 'AttributeType': 'S'}],
            BillingMode='PAY_PER_REQUEST'
        )
        s3 = boto3.client('s3', region_name='eu-west-3')
        s3.create_bucket(
            Bucket=BUCKET_NAME,
            CreateBucketConfiguration={'LocationConstraint': 'eu-west-3'}
        )
        table.put_item(Item={
            'session_id': 'test-session-123',
            'created_at': '2026-04-01T10:00:00Z',
            'status': 'questionnaire_done'
        })
        yield load_handler(), table


def assess_event(session_id, data):
    return {
        'pathParameters': {'session_id': session_id},
        'body': json.dumps(data)
    }


class TestAssessHandler:
    def test_returns_200(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(assess_event('test-session-123', good_sensor_data()), None)
        assert resp['statusCode'] == 200

    def test_response_contains_assessment_results(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(assess_event('test-session-123', good_sensor_data()), None)
        body = json.loads(resp['body'])
        assert 'assessment_results' in body

    def test_response_contains_all_exercise_keys(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(assess_event('test-session-123', good_sensor_data()), None)
        body = json.loads(resp['body'])
        assert set(body['assessment_results'].keys()) == {'Reach', 'Grasp', 'Manipulation', 'Release'}

    def test_response_contains_needed_training(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(assess_event('test-session-123', good_sensor_data()), None)
        body = json.loads(resp['body'])
        assert 'needed_training' in body
        assert isinstance(body['needed_training'], list)

    def test_response_contains_features(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(assess_event('test-session-123', good_sensor_data()), None)
        body = json.loads(resp['body'])
        assert 'features' in body

    def test_response_session_id_matches(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(assess_event('test-session-123', good_sensor_data()), None)
        body = json.loads(resp['body'])
        assert body['session_id'] == 'test-session-123'

    def test_response_status_is_assessed(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(assess_event('test-session-123', good_sensor_data()), None)
        body = json.loads(resp['body'])
        assert body['status'] == 'assessed'

    def test_dynamodb_updated_with_assessment_results(self, aws_setup):
        h, table = aws_setup
        h.handler(assess_event('test-session-123', good_sensor_data()), None)

        item = table.get_item(Key={'session_id': 'test-session-123'})['Item']
        assert 'assessment_results' in item
        assert item['status'] == 'assessed'

    def test_dynamodb_updated_with_assessment_features(self, aws_setup):
        h, table = aws_setup
        h.handler(assess_event('test-session-123', good_sensor_data()), None)

        item = table.get_item(Key={'session_id': 'test-session-123'})['Item']
        assert 'assessment_features' in item

    def test_cors_header_present(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(assess_event('test-session-123', good_sensor_data()), None)
        assert resp['headers']['Access-Control-Allow-Origin'] == '*'

    def test_s3_data_stored(self, aws_setup):
        h, _ = aws_setup
        h.handler(assess_event('test-session-123', good_sensor_data()), None)

        s3 = boto3.client('s3', region_name='eu-west-3')
        obj = s3.get_object(Bucket=BUCKET_NAME, Key='sensor-data/test-session-123/assess.json')
        stored = json.loads(obj['Body'].read())
        assert len(stored) == 20
