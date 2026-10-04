#!/usr/bin/env bash
# Prefer the CLI credential store over an inherited token.
# Exit 0 for help and every check outcome.
case "${1:-}" in
  --help|-h)
    printf '%s\n' 'Usage: 00-gh.sh' \
      'Check gh auth status -h github.com with GITHUB_TOKEN unset.'
    exit 0 ;;
esac
if ! command -v gh >/dev/null 2>&1; then
  printf '%s\n' 'gh: skip -- gh is not installed'
elif (unset GITHUB_TOKEN; gh auth status -h github.com >/dev/null 2>&1); then
  printf '%s\n' 'gh: ok -- authenticated with github.com'
else
  printf '%s\n' 'gh: fail -- not authenticated with github.com (fix: gh auth login)'
fi
exit 0
