#!/usr/bin/env bash
# Block commits that stage a binary file which is NOT tracked by Git LFS.
# Binary-ness uses git's own classification: `git diff --numstat` prints
# "-<TAB>-" for blobs git considers binary. LFS pointer files are text, so
# genuinely-LFS'd assets are never flagged.
set -euo pipefail

offenders=()
while IFS=$'\t' read -r added deleted path; do
  [ "$added" = "-" ] && [ "$deleted" = "-" ] || continue   # not binary → skip
  attr=$(git check-attr filter -- "$path" | sed 's/.*: //')
  [ "$attr" = "lfs" ] && continue                          # already LFS → ok
  offenders+=("$path")
done < <(git diff --cached --numstat --diff-filter=ACM)

if [ "${#offenders[@]}" -gt 0 ]; then
  echo "✖ lfs-guard: binary file(s) staged but NOT tracked by Git LFS:"
  printf '    %s\n' "${offenders[@]}"
  echo ""
  echo "  Track the extension in .gitattributes, e.g.:"
  echo "    echo '*.EXT filter=lfs diff=lfs merge=lfs -text' >> .gitattributes"
  echo "    git add .gitattributes && git add --renormalize <file>"
  exit 1
fi
