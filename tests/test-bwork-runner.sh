#!/usr/bin/env bash
set -euo pipefail
dotfiles=$(cd "$(dirname "$0")/.." && pwd)
helper="$dotfiles/bwork-boot-update"
assert_contains() { grep -Fq -- "$2" "$1" || { echo "missing '$2' in $1" >&2; exit 1; }; }
assert_count() { test "$(grep -Fc -- "$2" "$1")" = "$3" || { echo "wrong count for '$2' in $1" >&2; exit 1; }; }
make_runner() {
  local path=$1 calls=$2
  cat > "$path" <<EOF_RUNNER
#!/usr/bin/env bash
printf '%s\\n' "\$@" >> "$calls"
EOF_RUNNER
  chmod 0755 "$path"
}
run_missing() {
  local base test_home repo fake log
  base=$(mktemp -d); test_home="$base/test_home with spaces"; mkdir -p "$test_home"; repo="$test_home/missing"; fake="$test_home/fake-runner"; log="$test_home/boot.log"
  make_runner "$fake" "$test_home/calls"
  HOME="$test_home" BWORK_REPO="$repo" BWORK_RUNNER="$fake" BWORK_BOOT_LOG="$log" BWORK_BOOT_LOCK="$test_home/lock" "$helper"
  assert_contains "$log" 'no checkout'
  assert_contains "$test_home/calls" '--no-build'
}
run_non_main() {
  local test_home repo fake log
  test_home=$(mktemp -d); repo="$test_home/repo"; fake="$test_home/fake-runner"; log="$test_home/boot.log"
  git init -q "$repo"; git -C "$repo" config user.email test@example.invalid; git -C "$repo" config user.name test
  printf x > "$repo/file"; git -C "$repo" add file; git -C "$repo" commit -qm initial; git -C "$repo" branch -M feature
  make_runner "$fake" "$test_home/calls"
  HOME="$test_home" BWORK_REPO="$repo" BWORK_RUNNER="$fake" BWORK_BOOT_LOG="$log" BWORK_BOOT_LOCK="$test_home/lock" "$helper"
  assert_contains "$log" 'not on main'
  assert_contains "$test_home/calls" '--no-build'
}
run_dirty() {
  local test_home repo fake log
  test_home=$(mktemp -d); repo="$test_home/repo"; fake="$test_home/fake-runner"; log="$test_home/boot.log"
  git init -q -b main "$repo"; git -C "$repo" config user.email test@example.invalid; git -C "$repo" config user.name test
  printf x > "$repo/file"; git -C "$repo" add file; git -C "$repo" commit -qm initial
  printf y >> "$repo/file"
  make_runner "$fake" "$test_home/calls"
  HOME="$test_home" BWORK_REPO="$repo" BWORK_RUNNER="$fake" BWORK_BOOT_LOG="$log" BWORK_BOOT_LOCK="$test_home/lock" "$helper"
  assert_contains "$log" 'local changes'
  assert_contains "$test_home/calls" '--no-build'
}
run_tracking() {
  local test_home seed origin repo fake log
  test_home=$(mktemp -d); seed="$test_home/seed"; origin="$test_home/origin.git"; repo="$test_home/repo"; fake="$test_home/fake-runner"; log="$test_home/boot.log"
  git init -q --bare --initial-branch=main "$origin"
  git init -q -b main "$seed"; git -C "$seed" config user.email test@example.invalid; git -C "$seed" config user.name test
  printf x > "$seed/file"; git -C "$seed" add file; git -C "$seed" commit -qm initial; git -C "$seed" remote add origin "$origin"; git -C "$seed" push -q -u origin main
  git clone -q "$origin" "$repo"
  make_runner "$fake" "$test_home/fake-runner-calls"
  HOME="$test_home" BWORK_REPO="$repo" BWORK_RUNNER="$fake" BWORK_BOOT_LOG="$log" BWORK_BOOT_LOCK="$test_home/lock" "$helper"
  test "$(tail -n 1 "$test_home/fake-runner-calls")" = up
  printf y >> "$seed/file"; git -C "$seed" commit -qam update; git -C "$seed" push -q
  HOME="$test_home" BWORK_REPO="$repo" BWORK_RUNNER="$fake" BWORK_BOOT_LOG="$log" BWORK_BOOT_LOCK="$test_home/lock" "$helper"
  test "$(tail -n 1 "$test_home/fake-runner-calls")" = up
  HOME="$test_home" BWORK_REPO="$repo" BWORK_RUNNER="$fake" BWORK_BOOT_LOG="$log" BWORK_BOOT_LOCK="$test_home/lock" "$helper"
  test "$(tail -n 1 "$test_home/fake-runner-calls")" = up
  cat > "$fake" <<EOF_RUNNER
#!/usr/bin/env bash
printf '%s\\n' "\$@" >> "$test_home/fake-runner-calls"
[[ "\${2:-}" == --no-build ]]
EOF_RUNNER
  HOME="$test_home" BWORK_REPO="$repo" BWORK_RUNNER="$fake" BWORK_BOOT_LOG="$log" BWORK_BOOT_LOCK="$test_home/lock" "$helper"
  test "$(tail -n 1 "$test_home/fake-runner-calls")" = --no-build
  assert_contains "$log" 'build or start failed'
  cat > "$fake" <<EOF_RUNNER
#!/usr/bin/env bash
[[ ! -e /proc/\$\$/fd/9 ]] || exit 5
sleep 2 >/dev/null 2>&1 &
EOF_RUNNER
  HOME="$test_home" BWORK_REPO="$repo" BWORK_RUNNER="$fake" BWORK_BOOT_LOG="$log" BWORK_BOOT_LOCK="$test_home/lock" "$helper"
  flock -n "$test_home/lock" true
  mkdir "$test_home/stubs"
  cat > "$test_home/stubs/git" <<'EOF_GIT'
#!/usr/bin/env bash
[[ "${3:-}" != status ]] || exit 1
exec /usr/bin/git "$@"
EOF_GIT
  chmod 0755 "$test_home/stubs/git"
  HOME="$test_home" PATH="$test_home/stubs:$PATH" BWORK_REPO="$repo" BWORK_RUNNER="$fake" BWORK_BOOT_LOG="$log" BWORK_BOOT_LOCK="$test_home/lock" "$helper"
  assert_contains "$log" 'checkout status failed'
}
run_delayed_and_locked() {
  local test_home fake
  test_home=$(mktemp -d); fake="$test_home/runner"
  (sleep 1; make_runner "$fake" "$test_home/calls") &
  HOME="$test_home" BWORK_REPO="$test_home/missing" BWORK_RUNNER="$fake" BWORK_BOOT_WAIT_SECONDS=3 BWORK_BOOT_LOG="$test_home/log" BWORK_BOOT_LOCK="$test_home/lock" "$helper"
  assert_contains "$test_home/calls" --no-build
  rm "$test_home/calls"
  flock "$test_home/lock" env HOME="$test_home" BWORK_RUNNER="$fake" BWORK_BOOT_LOG="$test_home/log" BWORK_BOOT_LOCK="$test_home/lock" "$helper"
  test ! -e "$test_home/calls"
  assert_contains "$test_home/log" 'already running'
}
run_install_idempotence() {
  local test_home stubs dotfiles
  test_home=$(mktemp -d); stubs="$test_home/stubs"; dotfiles=$(cd "$(dirname "$0")/.." && pwd)
  mkdir -p "$stubs" "$test_home/.oh-my-zsh/custom/themes/powerlevel10k" "$test_home/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "$test_home/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
  cat > "$stubs/sudo" <<'EOF_SUDO'
#!/usr/bin/env bash
if [[ "${1:-}" == fuser ]]; then exit 1; fi
exit 0
EOF_SUDO
  chmod 0755 "$stubs/sudo"
  printf '# keep\n' > "$test_home/personalize"
  HOME="$test_home" PATH="$stubs:$PATH" bash "$dotfiles/install.sh" > "$test_home/install-1.log"
  HOME="$test_home" PATH="$stubs:$PATH" bash "$dotfiles/install.sh" > "$test_home/install-2.log"
  assert_count "$test_home/personalize" '# >>> bwork-runner boot update (dotfiles) >>>' 1
  assert_count "$test_home/personalize" '# keep' 1
  test -x "$test_home/.local/bin/bwork-boot-update"
}
run_existing_startup() {
  local test_home before
  test_home=$(mktemp -d)
  mkdir -p "$test_home/.local/bin"
  printf '#!/bin/sh\n/home/coder/.local/bin/bwork-boot-update &\n' > "$test_home/personalize"
  printf 'existing helper\n' > "$test_home/.local/bin/bwork-boot-update"
  before=$(sha256sum "$test_home/personalize" "$test_home/.local/bin/bwork-boot-update")
  HOME="$test_home" bash "$dotfiles/install-bwork-runner.sh" > "$test_home/install.log"
  test "$before" = "$(sha256sum "$test_home/personalize" "$test_home/.local/bin/bwork-boot-update")"
  assert_contains "$test_home/install.log" 'left its helper and hook unchanged'
  test_home=$(mktemp -d)
  mkdir -p "$test_home/.local/bin"
  printf 'external helper\n' > "$test_home/.local/bin/bwork-boot-update"
  HOME="$test_home" bash "$dotfiles/install-bwork-runner.sh" > "$test_home/install.log"
  test ! -e "$test_home/personalize"
  assert_contains "$test_home/.local/bin/bwork-boot-update" 'external helper'
}
run_startup_opt_out() {
  local test_home
  test_home=$(mktemp -d)
  mkdir -p "$test_home/.local/state/bwork-runner"
  touch "$test_home/.local/state/bwork-runner/boot.external"
  HOME="$test_home" bash "$dotfiles/install-bwork-runner.sh" > "$test_home/install.log"
  test ! -e "$test_home/personalize"
  test ! -e "$test_home/.local/bin/bwork-boot-update"
  assert_contains "$test_home/install.log" 'left its helper and hook unchanged'
}
run_owned_startup_upgrade() {
  local test_home
  test_home=$(mktemp -d)
  HOME="$test_home" bash "$dotfiles/install-bwork-runner.sh" > "$test_home/install.log"
  printf 'old managed helper\n' > "$test_home/.local/bin/bwork-boot-update"
  HOME="$test_home" bash "$dotfiles/install-bwork-runner.sh" >> "$test_home/install.log"
  cmp "$helper" "$test_home/.local/bin/bwork-boot-update"
  assert_count "$test_home/personalize" '# >>> bwork-runner boot update (dotfiles) >>>' 1
  printf 'other bwork-runner startup\n' >> "$test_home/personalize"
  printf 'preserve while external hook exists\n' > "$test_home/.local/bin/bwork-boot-update"
  HOME="$test_home" bash "$dotfiles/install-bwork-runner.sh" >> "$test_home/install.log"
  assert_contains "$test_home/.local/bin/bwork-boot-update" 'preserve while external hook exists'
}
run_missing
run_non_main
run_dirty
run_tracking
run_delayed_and_locked
run_install_idempotence
run_existing_startup
run_startup_opt_out
run_owned_startup_upgrade
echo 'portable runner bootstrap tests passed'
