#!/usr/bin/env python3
"""
Wrapper around git-sync-deps that runs downloads serially to avoid 429 rate limits.
"""
import sys
import os

# Force unbuffered output
sys.stdout = sys.__stdout__
os.environ['PYTHONUNBUFFERED'] = '1'

# Change to the skia directory (where DEPS file is)
script_dir = os.path.dirname(os.path.abspath(__file__))
skia_dir = os.path.join(script_dir, 'skia')
os.chdir(skia_dir)
print(f"Working directory: {os.getcwd()}", flush=True)

# Set the DEPS file path explicitly
os.environ['GIT_SYNC_DEPS_PATH'] = os.path.join(skia_dir, 'DEPS')

# Read the original script
git_sync_deps_path = os.path.join(skia_dir, 'tools', 'git-sync-deps')
with open(git_sync_deps_path, 'r') as f:
    original_code = f.read()

# Replace the multithread function to run serially
patched_code = original_code.replace(
    '''def multithread(function, list_of_arg_lists):
  anything_failed = False
  threads = []
  def hook(args):
    nonlocal anything_failed
    anything_failed = True
  threading.excepthook = hook
  for args in list_of_arg_lists:
    thread = threading.Thread(None, function, None, args)
    thread.start()
    threads.append(thread)
  for thread in threads:
    thread.join()
  if anything_failed:
    raise Exception("Thread failure detected")''',
    '''def multithread(function, list_of_arg_lists):
  # PATCHED: Run serially to avoid rate limiting
  import sys
  print("Running git-sync-deps in SERIAL mode to avoid 429 rate limits...", flush=True)
  print(f"Syncing {len(list_of_arg_lists)} dependencies one at a time...", flush=True)
  anything_failed = False
  for i, args in enumerate(list_of_arg_lists):
    print(f"  [{i+1}/{len(list_of_arg_lists)}] {args[3] if len(args) > 3 else args}", flush=True)
    sys.stdout.flush()
    try:
      function(*args)
    except Exception as e:
      print(f"Error: {e}", flush=True)
      anything_failed = True
  if anything_failed:
    raise Exception("One or more dependencies failed to sync")'''
)

# Replace the __name__ check at the end to call main directly
patched_code = patched_code.replace(
    "if __name__ == '__main__':",
    "if True:  # Patched to always run main"
)

# Execute the patched code
exec(compile(patched_code, git_sync_deps_path, 'exec'))
