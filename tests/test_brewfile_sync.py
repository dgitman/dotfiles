import os, pathlib, subprocess, tempfile, unittest, fcntl

SOURCE = pathlib.Path(__file__).resolve().parents[1]/'dot_local/bin/executable_brewfile-sync'

class BrewfileSyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='brewfile-sync-test-')
        self.root = pathlib.Path(self.temp.name)
        self.home = self.root/'home'; self.home.mkdir()
        self.repo = self.root/'repo'; self.repo.mkdir()
        self.bin = self.root/'bin'; self.bin.mkdir()
        self.env = dict(os.environ, PATH=str(self.bin)+':/usr/bin:/bin', GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_NOSYSTEM='1', XDG_STATE_HOME=str(self.root/'state'), TEST_REPO=str(self.repo), TEST_TARGET=str(self.home/'.Brewfile'), TEST_SNAPSHOT='brew "new"\n', GIT_AUTHOR_NAME='Test', GIT_AUTHOR_EMAIL='test@example.com', GIT_COMMITTER_NAME='Test', GIT_COMMITTER_EMAIL='test@example.com')
        self.env.pop('GIT_INDEX_FILE',None)
        self.git('init','-q')
        (self.repo/'dot_Brewfile').write_text('brew "old"\n')
        (self.home/'.Brewfile').write_text('brew "old"\n')
        (self.repo/'unrelated').write_text('initial\n')
        self.git('add','.'); self.git('-c','commit.gpgsign=false','commit','-qm','initial')
        self.initial=self.git('rev-parse','HEAD')
        self.remote=self.root/'remote.git'
        subprocess.check_call(['git','init','--bare','-q',str(self.remote)],env=self.env)
        self.git('remote','add','origin',str(self.remote))
        branch=self.git('branch','--show-current') or 'master'
        self.git('push','-u','origin',branch)
        self.mock('brew', '''for arg do case "$arg" in --file=*) target=${arg#--file=};; esac; done
printf '%s' "$TEST_SNAPSHOT" > "$target"
exit "${TEST_BREW_RC:-0}"
''')
        self.mock('chezmoi', '''for arg do
case "$arg" in
source-path) printf '%s/dot_Brewfile\\n' "$TEST_REPO"; exit 0;;
re-add) [ "${TEST_CHEZMOI_RC:-0}" = 0 ] || exit "$TEST_CHEZMOI_RC"; cp "$TEST_TARGET" "$TEST_REPO/dot_Brewfile"; exit 0;;
esac
done
exit 99
''')
        for tool in ['npm','mas','code']:
            self.mock(tool, 'exit "${TEST_COLLECTION_RC:-0}"\n')
        self.script=self.root/'brewfile-sync'
        self.script.write_text(SOURCE.read_text().replace('$HOME',str(self.home)))
    def tearDown(self): self.temp.cleanup()
    def mock(self,name,body):
        p=self.bin/name;p.write_text('#!/bin/sh\n'+body);p.chmod(0o755)
    def git(self,*args):
        return subprocess.check_output(['git','-C',str(self.repo),*args],env=self.env,text=True).strip()
    def run_sync(self,rc=0):
        r=subprocess.run(['/bin/bash',str(self.script)],env=self.env,capture_output=True,text=True)
        self.assertEqual(r.returncode,rc,r.stdout+r.stderr)
        return r
    def test_only_brewfile_committed_preserves_staged_and_unstaged(self):
        (self.repo/'unrelated').write_text('staged\n');self.git('add','unrelated')
        index=self.git('rev-parse',':unrelated')
        (self.repo/'unrelated').write_text('unstaged\n')
        self.git('config','commit.gpgsign','true')
        hooks=self.root/'hooks';hooks.mkdir()
        hook=hooks/'pre-commit';hook.write_text('#!/bin/sh\nexit 99\n');hook.chmod(0o755)
        self.git('config','core.hooksPath',str(hooks))
        self.run_sync()
        self.assertEqual(self.git('diff-tree','--no-commit-id','--name-only','-r','HEAD'),'dot_Brewfile')
        self.assertEqual(self.git('rev-parse',':unrelated'),index)
        self.assertEqual((self.repo/'unrelated').read_text(),'unstaged\n')
        self.assertEqual((self.repo/'dot_Brewfile').read_bytes(),(self.home/'.Brewfile').read_bytes())
    def test_no_change_no_commit(self):
        self.env['TEST_SNAPSHOT']='brew "old"\n';self.run_sync()
        self.assertEqual(self.git('rev-parse','HEAD'),self.initial)
    def test_dump_failure_preserves_snapshot(self):
        self.env['TEST_BREW_RC']='8';self.run_sync(8)
        self.assertEqual((self.home/'.Brewfile').read_text(),'brew "old"\n')
        self.assertEqual(self.git('rev-parse','HEAD'),self.initial)
    def test_collection_failure_preserves_snapshot(self):
        self.env['TEST_COLLECTION_RC']='7';self.run_sync(7)
        self.assertEqual((self.home/'.Brewfile').read_text(),'brew "old"\n')
    def test_empty_dump_preserves_snapshot(self):
        self.env['TEST_SNAPSHOT']='';self.run_sync(1)
        self.assertEqual((self.home/'.Brewfile').read_text(),'brew "old"\n')
    def test_readd_failure_does_not_commit(self):
        self.env['TEST_CHEZMOI_RC']='9';self.run_sync(9)
        self.assertEqual(self.git('rev-parse','HEAD'),self.initial)
        self.assertEqual((self.repo/'dot_Brewfile').read_text(),'brew "old"\n')
    def test_merge_in_progress_skips_changes(self):
        (self.repo/'.git/MERGE_HEAD').write_text(self.initial+'\n');self.run_sync(1)
        self.assertEqual((self.home/'.Brewfile').read_text(),'brew "old"\n')
    def test_concurrent_run_skips(self):
        state=self.root/'state/brewfile-sync';state.mkdir(parents=True)
        with (state/'run.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.run_sync()
        self.assertEqual(self.git('rev-parse','HEAD'),self.initial)
    def test_stale_lock_recovers(self):
        state=self.root/'state/brewfile-sync';state.mkdir(parents=True)
        (state/'run.lock').write_text('99999999\n');self.run_sync()
        self.assertNotEqual(self.git('rev-parse','HEAD'),self.initial)

if __name__ == '__main__': unittest.main(verbosity=2)
