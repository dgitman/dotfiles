import os, pathlib, subprocess, tempfile, unittest

HOOKS = pathlib.Path(__file__).resolve().parents[1]/'git-hooks'

class PrivacyHookTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='privacy-hook-test-')
        self.root = pathlib.Path(self.temp.name)
        self.home = self.root/'home'; self.home.mkdir()
        self.repo = self.root/'repo'; self.repo.mkdir()
        self.bin = self.root/'bin'; self.bin.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin)+':/usr/bin:/bin', GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_NOSYSTEM='1', GIT_AUTHOR_NAME='Test', GIT_AUTHOR_EMAIL='test@example.com', GIT_COMMITTER_NAME='Test', GIT_COMMITTER_EMAIL='test@example.com')
        self.env.pop('GIT_INDEX_FILE', None)
        chezmoi = self.bin/'chezmoi'
        chezmoi.write_text('#!/bin/sh\nprintf "me@personal.test\\nme@work.test\\nmyname\\n"\n'); chezmoi.chmod(0o755)
        self.git('init', '-q')
        self.git('config', 'core.hooksPath', str(HOOKS))
        self.git('config', 'commit.gpgsign', 'false')

    def tearDown(self):
        self.temp.cleanup()

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.repo, env=self.env, check=True, capture_output=True, text=True).stdout.strip()

    def commit(self, name, text, message='change'):
        (self.repo/name).write_text(text)
        self.git('add', name)
        return subprocess.run(['git', 'commit', '-qm', message], cwd=self.repo, env=self.env, capture_output=True, text=True)

    def test_allows_clean_commit(self):
        result = self.commit('config.tmpl', 'path = "{{ .chezmoi.homeDir }}/Developer"\n')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_blocks_home_path(self):
        result = self.commit('config.tmpl', f'path = "{self.home}/Developer"\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('config.tmpl', result.stderr)
        self.assertNotIn(str(self.home), result.stderr)

    def test_blocks_chezmoi_email_any_case(self):
        result = self.commit('config.toml', 'account = "ME@Work.test"\n')
        self.assertNotEqual(result.returncode, 0)

    def test_blocks_private_value_from_chezmoi(self):
        result = self.commit('notes.md', 'drive GoogleDrive-myname/Photos\n')
        self.assertNotEqual(result.returncode, 0)

    def test_blocks_commit_message(self):
        result = self.commit('notes.md', 'fine\n', message='Use me@personal.test for alerts')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('commit message', result.stderr)

    def test_blocks_literal_secret_value(self):
        key = 'SERVICE_API' + '_KEY'
        result = self.commit('mcp.json', f'{{"{key}": "abcdefghijklmnop1234"}}\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('secret-looking key', result.stderr)
        self.assertNotIn('abcdefghijklmnop1234', result.stderr)

    def test_allows_secret_from_1password(self):
        key = 'SERVICE_API' + '_KEY'
        ok = self.commit('mcp.json', f'{{"{key}": {{{{ onepasswordRead "op://vault/item/field" | toJson }}}}}}\n')
        self.assertEqual(ok.returncode, 0, ok.stderr)
        ref = self.commit('codex.toml', f'{key} = "op://vault/item/field"\n')
        self.assertEqual(ref.returncode, 0, ref.stderr)

    def test_ignores_removed_lines(self):
        self.assertEqual(self.commit('old.toml', 'clean\n').returncode, 0)
        (self.repo/'old.toml').write_text(f'{self.home}\n')
        self.git('add', 'old.toml')
        subprocess.run(['git', 'commit', '-qm', 'seed', '--no-verify'], cwd=self.repo, env=self.env, check=True)
        result = self.commit('old.toml', 'clean again\n')
        self.assertEqual(result.returncode, 0, result.stderr)

if __name__ == '__main__':
    unittest.main()
