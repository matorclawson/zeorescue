#!/usr/bin/env python3
"""Offline regressions; executes extracted functions, never the host recovery entrypoint.
Usage: python3 regression_test.py /path/to/source
"""
import os, pathlib, re, sqlite3, subprocess, sys, tempfile, unittest, json, shutil
ROOT = pathlib.Path(sys.argv.pop(1)).resolve() if len(sys.argv)>1 else pathlib.Path(__file__).resolve().parent
SRC = (ROOT / 'rescue.sh').read_text()

def function(name):
    m = re.search(r'^' + name + r'\(\).*?^}', SRC, re.M | re.S)
    if not m: raise AssertionError('missing function ' + name)
    return m.group()

def bash(text, env=None):
    return subprocess.run(['bash', '-c', 'set -uo pipefail\n' + text], text=True,
                          capture_output=True, env=env)

class Regression(unittest.TestCase):
    def test_live_wal_thread_selection(self):
        with tempfile.TemporaryDirectory() as td:
            p = pathlib.Path(td); db = p/'db'; roll = p/'roll'
            roll.write_text(json.dumps({'type':'session_meta','payload':{'id':'44444444-4444-4444-8444-444444444444','cwd':'/seat'}})+'\n'+json.dumps({'type':'turn_context','payload':{'approval_policy':'never','sandbox_policy':{'type':'danger-full-access'}}})+'\n')
            conn = sqlite3.connect(db)
            conn.execute('create table threads(id text, rollout_path text, cwd text, archived int, thread_source text, updated_at int)')
            conn.commit(); conn.execute('pragma journal_mode=wal'); conn.execute('pragma wal_autocheckpoint=0')
            conn.execute('insert into threads values (?,?,?,?,?,?)', ('44444444-4444-4444-8444-444444444444', str(roll), '/seat', 0, 'user', 1)); conn.commit()
            cli = p/'sqlite'; cli.write_text('#!'+sys.executable+'\nimport sqlite3,sys\nc=sqlite3.connect(sys.argv[1],uri=True)\nfor row in c.execute(sys.argv[2]): print(row[0])\n'); cli.chmod(0o700)
            env = dict(os.environ, DB=str(db), SQL=str(cli), JQ=shutil.which('jq'))
            history = re.search(r'^history\(\).*?^}', (ROOT/'records.sh').read_text(), re.M|re.S).group()
            result = bash(history + '\nUUID="^[0-9a-f-]{36}$"\nfail() { echo "$*" >&2; return 1; }; history codex 44444444-4444-4444-8444-444444444444 /seat', env)
            conn.close()
            self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
            self.assertEqual(json.loads(result.stdout)['path'], str(roll))

    def lsof_case(self, body, want, existing=True):
        with tempfile.TemporaryDirectory() as td:
            p=pathlib.Path(td); tool=p/'lsof'; tool.write_text('#!/bin/sh\n'+body+'\n'); tool.chmod(0o700)
            target=p/'rollout'
            if existing: target.touch()
            env=dict(os.environ,LSOF=str(tool),TARGET=str(target),STATE=td)
            result=bash(function('rollout_free')+'\nSTOP_TRIES=1; ROLLOUT_TRIES=1; pause() { :; }; rollout_free "$TARGET"',env)
            self.assertEqual(result.returncode==0,want,result.stdout+result.stderr)
    def test_lsof_silent_error(self): self.lsof_case('exit 2',False)
    def test_lsof_diagnostic_error(self): self.lsof_case('echo permission-denied >&2; exit 1',False)
    def test_lsof_no_holder(self): self.lsof_case('exit 1',True)
    def test_lsof_holder(self): self.lsof_case('echo 234; exit 0',False)
    def test_lsof_missing_rollout(self): self.lsof_case('exit 1',False,False)
    def test_lsof_empty_success_is_unknown(self): self.lsof_case('exit 0',False)

    def test_check_does_not_hide_unresolved(self):
        block=SRC[SRC.index('if [ $CHECK -eq 1 ]; then\n  echo "check:'):SRC.index('\nstopped=1')]
        result=bash('CHECK=1; ok=0; wrong=0; unresolved=1\n'+block)
        self.assertNotEqual(result.returncode,0,result.stdout)

    def test_unresolved_plan_stops_before_mutation(self):
        block=SRC[SRC.index('\nstopped=1'):]
        setup='''
APPLY=1; RESEAT=1; unresolved=1; failed=0; resumed=0; STAGGER=0
live=0; ok=0; running=0; resume=0; reseat=1
P_SEAT=(seat); P_PANE=(%1); P_CWD=(/seat); P_SID=(thread); P_HARNESS=(codex); P_ROLL=(roll)
work_list() { :; }; stop_seat() { echo MUTATION; return 1; }; stop_daemon() { echo MUTATION; }
'''
        result=bash(setup+block)
        self.assertNotIn('MUTATION',result.stdout)
        self.assertNotEqual(result.returncode,0)

    def test_no_unconditional_lossless_claim(self):
        self.assertNotIn('Each thread is intact and nothing is lost',function('recovery'))

    def test_process_enumeration_failure_is_not_stopped(self):
        with tempfile.TemporaryDirectory() as td:
            p=pathlib.Path(td)/'ps'; p.write_text('#!/bin/sh\nexit 2\n'); p.chmod(0o700)
            result=bash(function('holds')+'\nholds thread',dict(os.environ,PS_BIN=str(p)))
            self.assertEqual(result.returncode,2)

    def test_stop_refuses_unknown_process_state(self):
        result=bash(function('stop_seat')+'''\nTMUX_BIN=true; SOCKET=test; STOP_TRIES=1
holds() { return 2; }; pause() { :; }; stop_seat %1 /tmp thread
''')
        self.assertNotEqual(result.returncode,0)

    def test_no_automatic_sigkill(self):
        self.assertNotIn('"$KILL_BIN" -9',function('stop_daemon'))

    def test_daemon_failure_blocks_launch(self):
        block=SRC[SRC.index('\nstopped=1'):]
        setup='''
APPLY=1; RESEAT=1; unresolved=0; failed=0; resumed=0; STAGGER=0
live=0; ok=0; running=0; resume=1; reseat=0
P_SEAT=(seat); P_PANE=(''); P_CWD=(/seat); P_SID=(thread); P_HARNESS=(codex); P_ROLL=(roll); P_SESS=(seat); P_MODE=(''); P_WHY=(''); P_MARK=('')
STATE=/tmp
work_list() { :; }; stop_daemon() { return 1; }; rollout_free() { return 0; }
launch() { echo LAUNCHED; return 0; }; prove_codex() { return 0; }; recovery() { :; }
'''
        result=bash(setup+block)
        self.assertNotIn('LAUNCHED',result.stdout)
        self.assertNotEqual(result.returncode,0)

    def daemon_case(self, after, kill_exit, expected):
        with tempfile.TemporaryDirectory() as td:
            p=pathlib.Path(td)
            daemon='900 /home/.codex/packages/app-server-daemon/releases/1/bin/codex app-server --listen unix://s'
            (p/'before').write_text(daemon+'\n'); (p/'after').write_text(after+'\n')
            ps=p/'ps'; ps.write_text('#!/bin/sh\nif [ -f "$CASE/seen" ]; then cat "$CASE/after"; else touch "$CASE/seen"; cat "$CASE/before"; fi\n'); ps.chmod(0o700)
            kill=p/'kill'; kill.write_text('#!/bin/sh\necho "$*" >> "$CASE/kills"\nexit '+str(kill_exit)+'\n'); kill.chmod(0o700)
            env=dict(os.environ,CASE=td,PS_BIN=str(ps),KILL_BIN=str(kill))
            result=bash(function('stop_daemon')+'\npause() { :; }; stop_daemon',env)
            self.assertEqual(result.returncode==0,expected,result.stdout+result.stderr)
            self.assertNotIn('-9',(p/'kills').read_text())
    def test_daemon_survival_refuses(self): self.daemon_case('900 daemon',0,False)
    def test_daemon_signal_error_refuses(self): self.daemon_case('',1,False)
    def test_daemon_replacement_refuses(self): self.daemon_case('901 /home/.codex/packages/app-server-daemon/releases/1/bin/codex app-server',0,False)
    def test_daemon_exit_allows(self): self.daemon_case('',0,True)

if __name__ == '__main__': unittest.main(verbosity=2)
