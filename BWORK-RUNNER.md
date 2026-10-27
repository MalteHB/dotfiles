# bwork runner startup

The dotfiles installer installs `bwork-boot-update` in `~/.local/bin` and adds one marker-guarded block to `~/personalize`. Coder runs that script when a workspace starts. The block starts the helper detached. Keep that block before any `exit` or `exec` in a customized personalize script.

The helper uses `BWORK_REPO` when set and otherwise `$HOME/code`. It waits up to two minutes for the runner script to appear during startup. A clean `main` checkout tracking `origin/main` is fast-forwarded to the fetched commit. Every successful update check runs `bwork-runner up`; the wrapper reuses the installed binary when its source stamp matches, builds it when missing or stale, and retries a previous failed build. If building or starting fails, the helper tries the installed binary with `up --no-build`.

A dirty, non-main, missing, untracked, or unreadable checkout is never updated. If an executable runner script is available, those paths try only the installed binary. A missing script is logged and skipped after the wait. The helper serializes its work with a lock that is closed in all git and runner children.

The helper never reads or copies credentials. The initial `bin/bwork-runner up` sign-in happens once in a terminal on each machine. Without an installed binary, a dirty or non-main checkout cannot bootstrap automatically. On the first workspace start, the personalize hook may run before the dotfiles installer; the manual initial setup also covers that ordering.

Override `BWORK_REPO`, `BWORK_RUNNER`, `BWORK_BOOT_LOG`, `BWORK_BOOT_LOCK`, or `BWORK_BOOT_WAIT_SECONDS` in the Coder agent/template environment, not only in interactive shell startup files.
