import base64
import unittest

import ios_app_store as release
import ios_beta_release as apple
import local_apk as gate


class FakeApple:
    def __init__(self, *numbers):
        self.numbers = numbers

    def all(self, path):
        if path.startswith('/v1/apps?'):
            return [{'id': 'app', 'attributes': {'bundleId': apple.BUNDLE}}]
        if path.startswith('/v1/builds?'):
            return [{'attributes': {'version': number}} for number in self.numbers]
        raise AssertionError(path)


class StoreReleaseTests(unittest.TestCase):
    def test_selects_number_above_apple_and_repository_floors(self):
        store = FakeApple('302', '300', '301')
        self.assertEqual(release.apple_build_number(store, '300'), 303)
        self.assertEqual(release.apple_build_number(store, '304'), 305)

    def test_ambiguous_build_numbers_are_rejected(self):
        with self.assertRaises(gate.GateError):
            release.apple_build_number(FakeApple('1.2'), '302')

    def test_signed_candidate_requires_production_configuration(self):
        settings = {
            'BEECOUNT_SKINS_ENABLED': 'true',
            'BEECOUNT_PAID_SKINS_ENABLED': 'true',
            'BEECOUNT_SKIN_SALES': 'true',
            'BEECOUNT_SKIN_PRODUCTION_SALES': 'true',
        }

        def configuration(values):
            defines = ','.join(base64.b64encode(f'{key}={value}'.encode()).decode()
                               for key, value in values.items())
            return f'FLUTTER_BUILD_NAME=4.0.1\nFLUTTER_BUILD_NUMBER=303\nDART_DEFINES={defines}\n'

        release.verify_configuration(configuration(settings), '4.0.1', 303)
        for override in ({'BEECOUNT_SKIN_PRODUCTION_SALES': 'false'},
                         {'BEECOUNT_SKIN_METRICS_URL': 'https://metrics.example.com'},
                         {'BEECOUNT_OFFICIAL_QA': 'true'},
                         {'BEECOUNT_SKIN_PRODUCT_ID': 'alternative'}):
            with self.subTest(override=override), self.assertRaises(gate.GateError):
                release.verify_configuration(configuration({**settings, **override}),
                                             '4.0.1', 303)
