"""Routing tests for hope_ingest.handler.

The key invariant: the glove has no knowledge of phase. It always POSTs the
same payload to /ingest. The backend decides whether the batch is an
assessment or an exercise based on the session's state. We route on the
presence of `assessment_results` (not the `status` string), because status
can change independently when the patient submits the post-assessment
questionnaire.
"""
import json
import os
import importlib.util
import pytest
import boto3
from moto import mock_aws

HANDLER_PATH = os.path.join(os.path.dirname(__file__), '../lambdas/hope_ingest/handler.py')
TABLE_NAME = 'hope-sessions'
BUCKET_NAME = 'hope-data-test'
DEVICE_ID = 'hope-glove-01'


def _sample_batch(n=3):
    return [
        {
            'time': i * 50,
            'flex1': 40, 'flex2': 35,
            'fsr1': 50, 'fsr2': 45,
            'emg': 300,
            'ax': 1000, 'ay': -500, 'az': 16000,
            'gx': 10, 'gy': -5, 'gz': 3,
        }
        for i in range(n)
    ]


def _set_env():
    os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'
    os.environ['AWS_ACCESS_KEY_ID'] = 'test'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'test'
    os.environ['HOPE_BUCKET'] = BUCKET_NAME
    os.environ['TABLE'] = TABLE_NAME


def _load_handler():
    spec = importlib.util.spec_from_file_location('hope_ingest_handler', HANDLER_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def ingest_setup():
    with mock_aws():
        _set_env()
        ddb = boto3.resource('dynamodb', region_name='us-east-1')
        table = ddb.create_table(
            TableName=TABLE_NAME,
            KeySchema=[{'AttributeName': 'session_id', 'KeyType': 'HASH'}],
            AttributeDefinitions=[{'AttributeName': 'session_id', 'AttributeType': 'S'}],
            BillingMode='PAY_PER_REQUEST'
        )
        s3 = boto3.client('s3', region_name='us-east-1')
        s3.create_bucket(Bucket=BUCKET_NAME)
        handler_mod = _load_handler()
        yield handler_mod, table, s3


def _ingest_event(body):
    return {'body': json.dumps(body)}


def _put_session(table, session_id, **attrs):
    item = {'session_id': session_id, 'created_at': '2026-04-14T00:00:00+00:00'}
    item.update(attrs)
    table.put_item(Item=item)


class TestIngestRouting:
    def test_no_linked_session_returns_404(self, ingest_setup):
        handler_mod, _table, _s3 = ingest_setup
        resp = handler_mod.handler(_ingest_event(
            {'device_id': DEVICE_ID, 'data': _sample_batch()}
        ), None)
        assert resp['statusCode'] == 404
        assert 'no_active_session' in resp['body']

    def test_first_batch_runs_assessment(self, ingest_setup):
        """Fresh session, no assessment_results yet → run assessment."""
        handler_mod, table, _s3 = ingest_setup
        sid = 'sess-1'
        _put_session(table, sid, status='created', device_id=DEVICE_ID)

        resp = handler_mod.handler(_ingest_event(
            {'device_id': DEVICE_ID, 'data': _sample_batch(100)}
        ), None)
        body = json.loads(resp['body'])
        assert resp['statusCode'] == 200
        assert 'assessment_results' in body
        assert body['status'] == 'assessed'

    def test_second_batch_after_assessment_runs_exercise(self, ingest_setup):
        """Session already has assessment_results → run exercise regardless of status."""
        handler_mod, table, _s3 = ingest_setup
        sid = 'sess-2'
        _put_session(
            table, sid,
            status='assessed',
            device_id=DEVICE_ID,
            assessment_results={
                'Reach': 'FAIL', 'Grasp': 'PASS',
                'Manipulation': 'FAIL', 'Release': 'FAIL',
                'needed_training': ['Reach', 'Manipulation', 'Release'],
            },
        )

        resp = handler_mod.handler(_ingest_event(
            {'device_id': DEVICE_ID, 'data': _sample_batch(100)}
        ), None)
        body = json.loads(resp['body'])
        assert resp['statusCode'] == 200
        assert 'exercise_results' in body
        assert body['status'] == 'exercised'

    def test_questionnaire_status_does_not_confuse_router(self, ingest_setup):
        """Regression guard for the routing bug fixed on 2026-04-14.

        After assessment, the patient may submit the questionnaire which writes
        status='questionnaire_done'. The next /ingest batch (exercise data) must
        still be routed to the exercise branch — not re-run assessment and
        overwrite the results.
        """
        handler_mod, table, _s3 = ingest_setup
        sid = 'sess-3'
        original_results = {
            'Reach': 'PASS', 'Grasp': 'FAIL',
            'Manipulation': 'FAIL', 'Release': 'FAIL',
            'needed_training': ['Grasp', 'Manipulation', 'Release'],
        }
        _put_session(
            table, sid,
            # Status as it would look after PUT /questionnaire ran and
            # regressed status to questionnaire_done (old bug). Even if
            # save_questionnaire no longer does that, this keeps the router
            # honest against any other path that writes this status.
            status='questionnaire_done',
            device_id=DEVICE_ID,
            assessment_results=original_results,
        )

        resp = handler_mod.handler(_ingest_event(
            {'device_id': DEVICE_ID, 'data': _sample_batch(100)}
        ), None)
        body = json.loads(resp['body'])
        assert resp['statusCode'] == 200
        assert 'exercise_results' in body
        assert body['status'] == 'exercised'

        # Fetch the row and confirm original assessment_results are intact.
        item = table.get_item(Key={'session_id': sid}).get('Item', {})
        assert item['assessment_results']['Reach'] == 'PASS'
