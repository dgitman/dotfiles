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

SOURCE = pathlib.Path(__file__).resolve().parents[1]
GLOBAL_HOOKS = SOURCE/'dot_config/git/hooks'

class GlobalHookTests(unittest.TestCase):
    """Real git, wired up with the hook sections from dot_gitconfig.tmpl."""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='global-hook-test-')
        self.root = pathlib.Path(self.temp.name)
        self.home = self.root/'home'
        self.repo = self.root/'repo'; self.repo.mkdir()
        self.remote = self.root/'remote.git'
        self.bin = self.root/'bin'; self.bin.mkdir()
        hooks = self.home/'.config/git/hooks'; hooks.mkdir(parents=True)
        for name in ('pre-commit', 'pre-push'):
            hook = hooks/name
            hook.write_text((GLOBAL_HOOKS/f'executable_{name}').read_text()); hook.chmod(0o755)
        config = self.home/'.gitconfig'
        lines = subprocess.run(['git', 'config', '--file', str(SOURCE/'dot_gitconfig.tmpl'), '--get-regexp', r'^hook\.'], check=True, capture_output=True, text=True).stdout.splitlines()
        self.assertEqual(len(lines), 4)
        for line in lines:
            key, value = line.split(' ', 1)
            subprocess.run(['git', 'config', '--file', str(config), key, value], check=True)
        self.args = self.root/'coderabbit-args'
        self.scan = self.root/'pre-commit-args'
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin)+':/usr/bin:/bin', GIT_CONFIG_GLOBAL=str(config), GIT_CONFIG_NOSYSTEM='1', GIT_AUTHOR_NAME='Test', GIT_AUTHOR_EMAIL='test@example.com', GIT_COMMITTER_NAME='Test', GIT_COMMITTER_EMAIL='test@example.com')
        self.git('init', '-q', '-b', 'main')
        self.git('init', '-q', '--bare', str(self.remote))
        self.git('remote', 'add', 'origin', str(self.remote))
        self.git('commit', '-q', '--allow-empty', '-m', 'first')
        self.git('push', '-q', 'origin', 'main')  # coderabbit is not stubbed yet
        self.first = self.git('rev-parse', 'HEAD')
        self.git('commit', '-q', '--allow-empty', '-m', 'second')

    def tearDown(self):
        self.temp.cleanup()

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.repo, env=self.env, check=True, capture_output=True, text=True).stdout.strip()

    def stub(self, name, record, status=0):
        stub = self.bin/name
        stub.write_text(f'#!/bin/sh\necho "$@" >> "{record}"\nexit {status}\n'); stub.chmod(0o755)

    def run_git(self, *args):
        return subprocess.run(['git', *args], cwd=self.repo, env=self.env, capture_output=True, text=True)

    def push(self, *args):
        return self.run_git('push', 'origin', *(args or ('main',)))

    def commit(self):
        return self.run_git('commit', '--allow-empty', '-m', 'change')

    def repo_hook(self, name, body):
        hook = self.repo/'.git/hooks'/name
        hook.write_text(f'#!/bin/sh\n{body}\n'); hook.chmod(0o755)

    def pushed(self):
        return self.git('rev-parse', 'origin/main') == self.git('rev-parse', 'HEAD')

    def test_reviews_commits_since_remote(self):
        self.stub('coderabbit', self.args)
        result = self.push()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.args.read_text().split(), ['review', '--committed', '--gate', 'major', '--base-commit', self.first])
        self.assertTrue(self.pushed())

    def test_new_branch_has_no_base_commit(self):
        self.stub('coderabbit', self.args)
        self.git('switch', '-qc', 'feature')
        self.assertEqual(self.push('feature').returncode, 0)
        self.assertEqual(self.args.read_text().split(), ['review', '--committed', '--gate', 'major'])

    def test_major_findings_block_push(self):
        self.stub('coderabbit', self.args, 2)
        result = self.push()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Push blocked', result.stderr)
        self.assertFalse(self.pushed())

    def test_failed_review_warns_and_pushes(self):
        self.stub('coderabbit', self.args, 1)
        result = self.push()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('could not run', result.stderr)
        self.assertTrue(self.pushed())

    def test_missing_coderabbit_still_pushes(self):
        result = self.push()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('not installed', result.stderr)

    def test_skips_tag_pushes(self):
        self.stub('coderabbit', self.args, 2)
        self.git('tag', 'v1', self.first)
        self.assertEqual(self.push('v1').returncode, 0)
        self.assertFalse(self.args.exists())

    def test_repo_opt_out_skips_review(self):
        self.stub('coderabbit', self.args, 2)
        self.git('config', 'hook.coderabbit-review.enabled', 'false')
        result = self.push()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.args.exists())
        self.assertTrue(self.pushed())

    def test_no_verify_skips_review(self):
        self.stub('coderabbit', self.args, 2)
        self.assertEqual(self.push('--no-verify', 'main').returncode, 0)
        self.assertFalse(self.args.exists())

    def test_repo_pre_push_hook_gets_refs(self):
        self.stub('coderabbit', self.args)
        seen = self.root/'seen'
        self.repo_hook('pre-push', f'cat > "{seen}"')
        self.assertEqual(self.push().returncode, 0)
        self.assertIn('refs/heads/main', seen.read_text())

    def test_repo_pre_push_hook_can_block(self):
        self.stub('coderabbit', self.args)
        self.repo_hook('pre-push', 'exit 1')
        self.assertNotEqual(self.push().returncode, 0)
        self.assertFalse(self.pushed())

    def test_scan_runs_on_commit(self):
        self.stub('pre-commit', self.scan)
        (self.home/'.config/pre-commit').mkdir(parents=True)
        (self.home/'.config/pre-commit/config.yaml').write_text('repos: []\n')
        self.assertEqual(self.commit().returncode, 0)
        self.assertIn(str(self.home/'.config/pre-commit/config.yaml'), self.scan.read_text())

    def test_failed_scan_blocks_commit(self):
        self.stub('pre-commit', self.scan, 1)
        (self.home/'.config/pre-commit').mkdir(parents=True)
        (self.home/'.config/pre-commit/config.yaml').write_text('repos: []\n')
        self.assertNotEqual(self.commit().returncode, 0)

    def test_scan_runs_with_repo_hooks_path(self):
        self.stub('pre-commit', self.scan)
        (self.home/'.config/pre-commit').mkdir(parents=True)
        (self.home/'.config/pre-commit/config.yaml').write_text('repos: []\n')
        own = self.root/'own'; own.mkdir()
        ran = self.root/'own-ran'
        hook = own/'pre-commit'; hook.write_text(f'#!/bin/sh\ntouch "{ran}"\n'); hook.chmod(0o755)
        self.git('config', 'core.hooksPath', str(own))
        self.assertEqual(self.commit().returncode, 0)
        self.assertTrue(self.scan.exists())
        self.assertTrue(ran.exists())

    def test_repo_pre_commit_config_runs_once(self):
        self.stub('pre-commit', self.scan)
        (self.repo/'.pre-commit-config.yaml').write_text('repos: []\n')
        self.assertEqual(self.commit().returncode, 0)
        self.assertEqual(len(self.scan.read_text().splitlines()), 1)
        self.scan.unlink()
        self.repo_hook('pre-commit', 'exit 0')
        self.assertEqual(self.commit().returncode, 0)
        self.assertFalse(self.scan.exists())

if __name__ == '__main__':
    unittest.main()
