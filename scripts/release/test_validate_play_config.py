import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    'validate_play_config', Path(__file__).with_name('validate_play_config.py')
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PlayConfigTest(unittest.TestCase):
    def test_requires_a_real_https_sync_endpoint(self):
        for value in ('', 'http://sync.example.com', 'https://localhost',
                      'https://127.0.0.1', 'https://user:pass@sync.example.com',
                      'https://sync.example.com/path?token=secret',
                      'https://sync.example.invalid', 'https://sync..example.com',
                      'https://sync.example.com\n.attacker.example',
                      'https://127.0.0.1.', 'https://localhost.',
                      'https://sync.example.com:8443/service'):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    module.validate_endpoint(value)

    def test_accepts_a_configured_https_origin(self):
        self.assertEqual(module.validate_endpoint('https://sync.example.com'),
                         'https://sync.example.com')
        self.assertEqual(module.validate_endpoint('https://sync.example.com:8443/service/'),
                         'https://sync.example.com:8443/service/')


if __name__ == '__main__':
    unittest.main()
