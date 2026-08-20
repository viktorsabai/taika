import subprocess

cmd = ['git', 'push', 'origin', '2026-01-21-k7hb-d2004']
proc = subprocess.run(cmd, text=True, capture_output=True)
print(proc.stdout)
print(proc.stderr)
raise SystemExit(proc.returncode)
