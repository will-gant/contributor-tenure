#!/usr/bin/env bash

set -e

current_dir=$(pwd)

if [[ -z "$1" ]]; then
  echo "Error: first argument must be the path to the git repo"
  exit 1
fi

if [[ ! -d "$1" ]]; then
  echo "Error: $1 is not a directory"
  exit 1
fi

if ! git -C "$1" rev-parse; then
  echo "Error: $1 is not a git repo"
  exit 1
fi

if ! command -v yq &> /dev/null; then
  echo "Error: yq is not installed or not in PATH"
  exit 1
fi

case "$1" in
  /*) repo_root="$1" ;;
  *) repo_root="$(pwd)/$1" ;;
esac

if [[ -n "$2" ]]; then
    filepath="$2"
else
  filepath="$current_dir/git_contributors.yaml"
fi

if [[ -f "$filepath" ]]; then
  echo "Error: $filepath already exists"
  exit 1
fi

echo 'emails:' > "$filepath"
emails=$(git -C "$repo_root" log --format='%ae' | sort --unique)
for email in $emails; do
  echo "  $email: null" >> "$filepath"
done

echo 'names:' >> "$filepath"
names=$(git -C "$repo_root" log --format='%an' | sort --unique)
for name in $names; do
  echo "  $name: null" >> "$filepath"
done

if ! yq . "$filepath" > /dev/null 2>&1; then
  echo "Error: failed to generate valid yaml"
  exit 1
fi

email_count=$(yq '.emails | length' "$filepath")
name_count=$(yq '.names | length' "$filepath")

echo "Created a template containing $email_count emails and $name_count names at $filepath"