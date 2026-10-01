#!/usr/bin/env python3
"""Test migrations in a disposable local PostgreSQL cluster, never a live database."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    candidates = [os.environ.get('MARGOT_PG_BIN'), '/opt/homebrew/opt/postgresql@17/bin',
                  '/usr/local/opt/postgresql@17/bin', '/usr/lib/postgresql/17/bin']
    if shutil.which('initdb'):
        candidates.append(str(Path(shutil.which('initdb')).parent))
    pg_bin = next((Path(p) for p in candidates if p and (Path(p) / 'initdb').is_file()), None)
    if pg_bin is None:
        sys.exit('Install local PostgreSQL 17+ or set MARGOT_PG_BIN. No live database will be used.')
    version = subprocess.check_output([str(pg_bin / 'postgres'), '--version'], text=True)
    if int(re.search(r'(\d+)\.', version)[1]) < 17:
        sys.exit('PostgreSQL 17+ required. Point MARGOT_PG_BIN at that installation.')
    env = {k: v for k, v in os.environ.items() if not k.startswith('PG')}

    def run(binary, *args):
        result = subprocess.run([str(pg_bin / binary), *map(str, args)], env=env,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError(result.stdout)
        return result.stdout

    # Short private Unix socket path, no TCP listener and no inherited PG* settings.
    with tempfile.TemporaryDirectory(prefix='margot-pg-', dir='/tmp') as temp:
        folder = Path(temp)
        data = folder / 'data'
        run('initdb', '-D', data, '-U', 'margot_test', '--auth=trust', '--encoding=UTF8', '--no-locale')
        started = False
        try:
            run('pg_ctl', '-D', data, '-l', folder / 'postgres.log', '-o',
                f"-k {folder} -p 55439 -c listen_addresses=''", '-w', 'start')
            started = True
            files = [ROOT / 'tests/bootstrap.sql', *sorted((ROOT / 'supabase/migrations').glob('*.sql')),
                     ROOT / 'tests/database.sql', ROOT / 'supabase/verify.sql', ROOT / 'supabase/smoke.sql']
            for file in files:
                transaction = ['-1'] if file.parent.name == 'migrations' else []
                output = run('psql', '-X', '-v', 'ON_ERROR_STOP=1', '-h', folder, '-p', '55439',
                             '-U', 'margot_test', '-d', 'postgres', *transaction, '-f', file)
                print(f'PASS {file.relative_to(ROOT)}')
                if file.name == 'database.sql':
                    print(output)
        finally:
            if started:
                run('pg_ctl', '-D', data, '-m', 'immediate', '-w', 'stop')
    print('PASS: disposable database removed; no live service contacted')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError) as exc:
        sys.exit(str(exc))
