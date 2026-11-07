import json, os, pathlib, subprocess, sys, tempfile, unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1]/'dot_local/bin/executable_repo-secret-scan'
SECRET = 'do-not-print-this-value'

def finding(verified, file='config.env'):
    return json.dumps({'DetectorName': 'Github', 'Verified': verified, 'Raw': SECRET, 'RawV2': SECRET, 'Redacted': SECRET,
                       'SourceMetadata': {'Data': {'Git': {'commit': 'abcdef1234567', 'file': file, 'line': 3, 'email': SECRET}}}})

class RepoSecretScanTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='repo-secret-scan-test-')
        self.root = pathlib.Path(self.temp.name)
        self.bin = self.root/'bin'; self.bin.mkdir()
        self.calls = self.root/'calls'
        self.repo = self.root/'owner/repo'; (self.repo/'.git').mkdir(parents=True)
        (self.repo/'.git/index').write_text('')
        self.env = dict(os.environ, PATH=str(self.bin)+':/usr/bin:/bin', HOME=str(self.root))

    def tearDown(self):
        self.temp.cleanup()

    def trufflehog(self, *lines, status=0):
        output = self.root/'output'; output.write_text(''.join(line+'\n' for line in lines))
        stub = self.bin/'trufflehog'
        stub.write_text(f'#!/bin/sh\necho "$@" >> "{self.calls}"\ncat "{output}"\necho "{SECRET}" >&2\nexit {status}\n'); stub.chmod(0o755)

    def scan(self, *paths):
        return subprocess.run([sys.executable, str(SCRIPT), *map(str, paths)], env=self.env, capture_output=True, text=True)

    def test_clean_repo(self):
        self.trufflehog()
        result = self.scan(self.repo)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'scanned 1 repos\n')

    def test_scans_history_with_verified_and_unknown_results(self):
        self.trufflehog()
        self.scan(self.repo)
        args = self.calls.read_text().split()
        self.assertEqual(args[:2], ['git', f'file://{self.repo}'])
        self.assertIn('--results=verified,unknown', args)

    def test_live_credential_fails_without_printing_it(self):
        self.trufflehog(finding(True))
        result = self.scan(self.repo)
        self.assertEqual(result.returncode, 1)
        self.assertIn('VERIFIED owner/repo Github config.env:3 commit abcdef1', result.stdout)
        self.assertNotIn(SECRET, result.stdout+result.stderr)

    def test_unknown_result_is_reported_but_passes(self):
        self.trufflehog(finding(False))
        result = self.scan(self.repo)
        self.assertEqual(result.returncode, 0)
        self.assertIn('UNKNOWN owner/repo Github', result.stdout)
        self.assertNotIn(SECRET, result.stdout+result.stderr)

    def test_failed_scan_is_reported(self):
        self.trufflehog(status=1)
        result = self.scan(self.repo)
        self.assertIn('FAILED owner/repo exit 1', result.stdout)

    def ignore(self, text):
        path = self.root/'.config/repo-secret-scan/ignore'
        path.parent.mkdir(parents=True, exist_ok=True); path.write_text(text)

    def test_ignored_findings_are_counted_not_printed(self):
        self.trufflehog(finding(True), finding(False, 'other.env'))
        self.ignore('# reviewed\nowner/repo Github config.env  # public test key\nowner/repo Github other.env:3 commit abcdef1\n')
        result = self.scan(self.repo)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, 'scanned 1 repos, 2 findings ignored\n')

    def test_ignore_matches_whole_words_only(self):
        self.trufflehog(finding(True))
        self.ignore('owner/rep\nowner/repo Github config\n')
        result = self.scan(self.repo)
        self.assertEqual(result.returncode, 1)
        self.assertIn('VERIFIED owner/repo Github config.env:3', result.stdout)

    def test_skips_worktrees_empty_repos_and_non_repos(self):
        self.trufflehog()
        worktree = self.root/'owner/worktree'; worktree.mkdir()
        (worktree/'.git').write_text('gitdir: elsewhere\n')
        empty = self.root/'owner/empty'; (empty/'.git').mkdir(parents=True)
        plain = self.root/'owner/plain'; plain.mkdir()
        result = self.scan(self.repo, worktree, empty, plain, self.root/'owner/missing')
        self.assertIn('scanned 1 repos', result.stdout)
        self.assertEqual(len(self.calls.read_text().splitlines()), 1)

if __name__ == '__main__':
    unittest.main()
