import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('margot', ROOT / 'scripts/margot.py')
margot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(margot)


class HelpersTest(unittest.TestCase):
    def setUp(self):
        self.profile = margot.demo_profile()
        self.data = margot.read_json(ROOT / 'examples/intro.json')

    def test_normalizes_without_merging_aliases(self):
        self.assertEqual(margot.email(' Alex.Smith+vc@Example.com '), 'alex.smith+vc@example.com')
        for bad in ['a@example.com,b@example.com', 'A <a@example.com>', 'a@b.com\nBcc: c@d.com']:
            with self.assertRaises(ValueError):
                margot.email(bad)

    def test_all_templates_render(self):
        for name in margot.TEMPLATES:
            data = self.data if name == 'investor-intro' else margot.read_json(ROOT / 'examples/follow-up.json')
            result = margot.render(name, data, self.profile)
            self.assertNotIn('{{', result['body_text'])
            self.assertEqual(len(result['template_sha256']), 64)
            self.assertEqual(result['recipient_email'], 'alex@example.com')

    def test_missing_fact_or_unapproved_copy_blocks_render(self):
        for field, value in [('fundraising_context', ''), ('templates_approved', False), ('timezone', '')]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                margot.render('investor-intro', self.data, {**self.profile, field: value})
        with self.assertRaises(ValueError):
            margot.render('investor-intro', {**self.data, 'personalization': ''}, self.profile)

    def test_recipient_cannot_override_identity(self):
        with self.assertRaises(ValueError):
            margot.render('investor-intro', {**self.data, 'sender_email': 'other@example.com'}, self.profile)

    def test_subject_injection_is_rejected(self):
        for value in ['Pink\nBcc: other@example.com', 'Pink\n\nInjected body']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                margot.render('investor-intro', self.data, {**self.profile, 'company_name': value})

    def test_windows_newlines_render_with_exact_source_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'templates').mkdir()
            raw = b'Subject: Hello\r\n\r\nHi {{first_name}}\r\n'
            (root / 'templates/investor-intro.md').write_bytes(raw)
            result = margot.render('investor-intro', self.data, self.profile, root)
            self.assertEqual(result['body_text'], 'Hi Alex\n')
            self.assertEqual(result['template_sha256'], margot.hashlib.sha256(raw).hexdigest())

    def test_followup_requires_verified_thread(self):
        data = margot.read_json(ROOT / 'examples/follow-up.json')
        del data['gmail_thread_id']
        with self.assertRaises(ValueError):
            margot.render('follow-up-1', data, self.profile)

    def test_nested_placeholder_is_rejected(self):
        with self.assertRaises(ValueError):
            margot.render('investor-intro', {**self.data, 'personalization': '{{missing}}'}, self.profile)

    def test_hash_tracks_template_bytes_even_without_commit(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'templates').mkdir()
            target = root / 'templates/investor-intro.md'
            target.write_text('Subject: Hello\n\nHello {{first_name}}\n', encoding='utf-8')
            first = margot.render('investor-intro', self.data, self.profile, root)
            target.write_text('Subject: Hello\n\nWelcome {{first_name}}\n', encoding='utf-8')
            second = margot.render('investor-intro', self.data, self.profile, root)
            self.assertNotEqual(first['template_sha256'], second['template_sha256'])

    def test_due_sql_uses_current_config_and_requires_offset(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'config').mkdir()
            config = margot.settings()
            config['first_follow_up_days'] = 7
            (root / 'config/outreach.json').write_text(json.dumps(config))
            self.assertIn(', 7, 7)', margot.due_sql('2026-10-01T12:00:00-06:00', root))
            with self.assertRaises(ValueError):
                margot.due_sql('2026-10-01T12:00:00', root)

    def test_sql_literal_escapes_apostrophes(self):
        self.assertEqual(margot.sql_literal("O'Brien"), "'O''Brien'")

    def test_fresh_checkout_setup_and_demo_are_offline(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for folder in ('scripts', 'config', 'templates', 'examples'):
                shutil.copytree(ROOT / folder, root / folder, ignore=shutil.ignore_patterns('__pycache__', 'local.json'))

            def cli(*args):
                return subprocess.run([sys.executable, str(root / 'scripts/margot.py'), *args],
                                      cwd=root, text=True, capture_output=True)

            self.assertEqual(cli('doctor').returncode, 1)
            self.assertEqual(cli('init').returncode, 0)
            profile = root / 'config/local.json'
            original = profile.read_text()
            self.assertEqual(json.loads(original)['company_name'], 'Pink Fitness Club')
            self.assertEqual(cli('init').returncode, 0)
            self.assertEqual(profile.read_text(), original)
            check = cli('doctor')
            self.assertEqual(check.returncode, 1)
            self.assertIn('UNVERIFIED: Gmail', check.stdout)
            self.assertEqual(cli('render', 'investor-intro', '--data', 'examples/intro.json').returncode, 1)
            preview = cli('render', 'investor-intro', '--data', 'examples/intro.json', '--demo', '--output', '.local/preview.json')
            self.assertEqual(preview.returncode, 0, preview.stderr)
            self.assertTrue(json.loads((root / '.local/preview.json').read_text())['demo_only'])
            self.assertEqual(cli('render', 'investor-intro', '--data', 'examples/intro.json', '--demo', '--output', 'tracked.json').returncode, 1)
            self.assertFalse((root / 'tracked.json').exists())


if __name__ == '__main__':
    unittest.main()
