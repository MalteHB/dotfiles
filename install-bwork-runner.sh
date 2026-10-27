#!/usr/bin/env bash
set -euo pipefail

dotfiles_dir="$(cd "$(dirname "$0")" && pwd)"
personalize="$HOME/personalize"
helper="$HOME/.local/bin/bwork-boot-update"
marker="# >>> bwork-runner boot update (dotfiles) >>>"
end_marker="# <<< bwork-runner boot update (dotfiles) <<<"

managed=false
if [[ -f "$personalize" ]] && grep -qFx "$marker" "$personalize"; then
  managed=true
fi

external=false
if [[ -e "$HOME/.local/state/bwork-runner/boot.external" ]] || { [[ -e "$helper" ]] && [[ "$managed" == false ]]; }; then
  external=true
elif [[ -f "$personalize" ]] && awk -v start="$marker" -v end="$end_marker" '
  $0 == start { inside=1; next }
  $0 == end { inside=0; next }
  !inside && /bwork-runner|bwork-boot/ { found=1 }
  END { exit !found }
' "$personalize"; then
  external=true
fi

if [[ "$external" == true ]]; then
  echo "Existing bwork startup found; dotfiles left its helper and hook unchanged."
  exit 0
fi

install -D -m 0755 "$dotfiles_dir/bwork-boot-update" "$helper"
if [[ ! -e "$personalize" ]]; then
  printf '#!/usr/bin/env bash\n' > "$personalize"
fi
chmod 0755 "$personalize"
if [[ "$managed" == false ]]; then
  cat >> "$personalize" <<'EOF'

# >>> bwork-runner boot update (dotfiles) >>>
if [ -x "$HOME/.local/bin/bwork-boot-update" ]; then
  mkdir -p "$HOME/.local/state/bwork-runner"
  setsid -f "$HOME/.local/bin/bwork-boot-update" < /dev/null > /dev/null 2>&1 || true
fi
# <<< bwork-runner boot update (dotfiles) <<<
EOF
fi
echo "Portable bwork startup installed."
