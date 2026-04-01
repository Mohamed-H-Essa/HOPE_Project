"""Level 2 tests — hope_exercise handler (mocked AWS)."""
import json
import os
import sys
import importlib.util
import pytest
import boto3
from moto import mock_aws

HANDLER_PATH = os.path.join(os.path.dirname(__file__), '../lambdas/hope_exercise/handler.py')
TABLE_NAME = 'hope-sessions'
BUCKET_NAME = 'hope-data-test'


def set_aws_env():
    os.environ['AWS_DEFAULT_REGION'] = 'eu-west-3'
    os.environ['AWS_ACCESS_KEY_ID'] = 'test'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'test'
    os.environ['HOPE_BUCKET'] = BUCKET_NAME


def load_handler():
    spec = importlib.util.spec_from_file_location('hope_exercise_handler', HANDLER_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def make_sample(i, flex1=70, flex2=70, fsr1=80, fsr2=80):
    return {"time": i * 50, "ax": 0.5, "ay": 0.1, "az": 0.1,
            "gx": 5.0, "gy": 0, "gz": 0,
            "flex1": flex1, "flex2": flex2, "fsr1": fsr1, "fsr2": fsr2, "emg": 50}


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
            'session_id': 'test-session-456',
            'created_at': '2026-04-01T10:00:00Z',
            'status': 'assessed'
        })
        yield load_handler(), table


def exercise_event(session_id, data, exercise_name):
    return {
        'pathParameters': {'session_id': session_id},
        'body': json.dumps({'data': data, 'exercise': exercise_name})
    }


class TestExerciseHandler:
    def test_returns_200(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(exercise_event('test-session-456', good_sensor_data(), 'Grasp'), None)
        assert resp['statusCode'] == 200

    def test_response_contains_exercise_results(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(exercise_event('test-session-456', good_sensor_data(), 'Grasp'), None)
        body = json.loads(resp['body'])
        assert 'exercise_results' in body

    def test_exercise_results_has_overall_percent(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(exercise_event('test-session-456', good_sensor_data(), 'Grasp'), None)
        body = json.loads(resp['body'])
        assert 'overall_percent' in body['exercise_results']

    def test_exercise_results_has_message(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(exercise_event('test-session-456', good_sensor_data(), 'Grasp'), None)
        body = json.loads(resp['body'])
        assert 'message' in body['exercise_results']

    def test_exercise_results_has_features(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(exercise_event('test-session-456', good_sensor_data(), 'Grasp'), None)
        body = json.loads(resp['body'])
        assert 'features' in body['exercise_results']

    def test_session_id_in_response(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(exercise_event('test-session-456', good_sensor_data(), 'Grasp'), None)
        body = json.loads(resp['body'])
        assert body['session_id'] == 'test-session-456'

    def test_status_is_exercised(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(exercise_event('test-session-456', good_sensor_data(), 'Grasp'), None)
        body = json.loads(resp['body'])
        assert body['status'] == 'exercised'

    def test_dynamodb_updated_with_exercise_results(self, aws_setup):
        h, table = aws_setup
        h.handler(exercise_event('test-session-456', good_sensor_data(), 'Grasp'), None)

        item = table.get_item(Key={'session_id': 'test-session-456'})['Item']
        assert 'exercise_results' in item
        assert item['status'] == 'exercised'

    def test_dynamodb_s3_key_stored(self, aws_setup):
        h, table = aws_setup
        h.handler(exercise_event('test-session-456', good_sensor_data(), 'Grasp'), None)

        item = table.get_item(Key={'session_id': 'test-session-456'})['Item']
        assert item.get('sensor_data_exercise_s3') == 'sensor-data/test-session-456/exercise.json'

    def test_cors_header_present(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(exercise_event('test-session-456', good_sensor_data(), 'Grasp'), None)
        assert resp['headers']['Access-Control-Allow-Origin'] == '*'

    def test_reach_exercise(self, aws_setup):
        h, _ = aws_setup
        resp = h.handler(exercise_event('test-session-456', good_sensor_data(), 'Reach'), None)
        assert resp['statusCode'] == 200
        body = json.loads(resp['body'])
        assert body['exercise_results']['exercise'] == 'Reach'

    def test_s3_data_stored(self, aws_setup):
        h, _ = aws_setup
        h.handler(exercise_event('test-session-456', good_sensor_data(), 'Grasp'), None)

        s3 = boto3.client('s3', region_name='eu-west-3')
        obj = s3.get_object(Bucket=BUCKET_NAME, Key='sensor-data/test-session-456/exercise.json')
        stored = json.loads(obj['Body'].read())
        assert 'data' in stored
        assert 'exercise' in stored
