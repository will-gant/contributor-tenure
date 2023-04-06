#!/usr/bin/env bash

set -e

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

case "$1" in
  /*) repo_root="$1" ;;
  *) repo_root="$(pwd)/$1" ;;
esac

if [[ -z "$2" ]]; then
  contributors_config="${repo_root}/git_contributors.yaml"
else
  contributors_config="$1"
fi

if [[ -z "$3" ]]; then
  output_csv="${repo_root}/git_contributors.csv"
else
  output_csv="$2"
fi

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "Error: minimum of bash 4.0.0 required, ran with bash $BASH_VERSION"
  exit 1
fi

if ! command -v yq &> /dev/null; then
  echo "Error: yq is not installed or not in PATH"
  exit 1
fi

total_commit_days=0
total_contributors=0
ignore_if_committed_in_last_days=90
echo "Name,First Commit,Last Commit,Commit Days" > "$output_csv"
unidentified_emails=0

function identify() {
  id_from_email=$(yq ".emails.[\"$1\"]" "$contributors_config")
  if [[ "$id_from_email" == 'null' ]]; then
    committer_name="$(git -C "$repo_root" log --pretty=format:%an --author="$1" | head -1)"
    if [[ -z "$committer_name" ]]; then
      echo "unknown"
      return
    fi
    id_from_committer_name=$(yq ".names.[\"$committer_name\"]" "$contributors_config")
    if [[ "$id_from_committer_name" == 'null' ]]; then
      echo "unknown"
      return
    else
      echo "$id_from_committer_name"
    fi
  else
    echo "$id_from_email"
  fi
}

echo "grabbing all unique emails from git log..."
emails=$(git -C "$repo_root" log --pretty=format:%ae | sort -u)
emails_count="$(echo $emails | wc -w | tr -d ' ')"
config_emails_count=$(yq ".emails | length" "$contributors_config")
config_names_count=$(yq ".names | length" "$contributors_config")
echo "found $emails_count unique emails in git log, and $config_emails_count emails and $config_names_count names that a nice human has configured for me in $contributors_config"

echo "using an excruciatingly inefficient technique to map committer email addresses and names to known contributors in $contributors_config and calculating first and last commit dates..."
declare -A first_commit_map
declare -A last_commit_map

email_index=1
for email in $emails; do
  unset last_commit first_commit
  echo -ne "$email_index of $emails_count"\\r
  email_index=$(( email_index + 1 ))

  if [[ -z "$email" ]]; then
    continue
  fi

  last_commit=$(git -C "$repo_root" log -1 --pretty=format:%ct --author="$email")
  first_commit=$(git -C "$repo_root" log --reverse --pretty=format:%ct --author="$email" | head -1)

  if [[ -z "$last_commit" ]] || [[ -z "$first_commit" ]]; then
    continue
  fi

  committer_id=$(identify "$email")
  if [[ "$committer_id" == 'unknown' ]] || [[ -z "$committer_id" ]]; then
    unidentified_emails=$(( unidentified_emails + 1 ))
    continue
  fi

  committer_id=$(echo "$committer_id" | tr ' ' '_')

  if [[ -z ${first_commit_map["$committer_id"]} ]]; then
    first_commit_map["$committer_id"]=$first_commit
  elif [[ $first_commit -lt ${first_commit_map["$committer_id"]} ]]; then
    first_commit_map["$committer_id"]=$first_commit
  fi

  if [[ -z ${last_commit_map["$committer_id"]} ]]; then
    last_commit_map["$committer_id"]=$last_commit
  elif [[ $last_commit -gt ${last_commit_map["$committer_id"]} ]]; then
    last_commit_map["$committer_id"]=$last_commit
  fi
done

echo "calculating total commit days for each contributor..."
current_committers=0
for committer_id in "${!first_commit_map[@]}"; do
  unset days_since_last_commit first_commit last_commit commit_days

  if [[ -z "$committer_id" ]] || [[ -z ${last_commit_map["$committer_id"]} ]]; then
    continue
  fi

  days_since_last_commit=$(( ( $(date +%s) - ${last_commit_map["$committer_id"]} ) / 86400 ))
  if [[ $days_since_last_commit -lt $ignore_if_committed_in_last_days ]]; then
    current_committers=$(( current_committers + 1 ))
    continue
  fi

  first_commit=${first_commit_map["$committer_id"]}
  first_commit_human_readable=$(date -r $first_commit)
  last_commit=${last_commit_map["$committer_id"]}
  last_commit_human_readable=$(date -r $last_commit)
  commit_days=$(( (last_commit - first_commit) / 86400 ))

  committer_id=$(echo "$committer_id" | tr '_' ' ')
  echo "$committer_id,$first_commit_human_readable,$last_commit_human_readable,$commit_days" >> "$output_csv"

  total_commit_days=$(( total_commit_days + commit_days ))
  total_contributors=$(( total_contributors + 1 ))
done

if [[ $unidentified_emails -gt 0 ]]; then
  echo "Unable to identify $unidentified_emails contributors :-("
fi

echo "Ignored $current_committers committers who have committed in the last $ignore_if_committed_in_last_days days"

average_commit_days=$(( total_commit_days / total_contributors ))
echo "Average commit days: $average_commit_days"
echo "Total commit days: $total_commit_days"
echo "Total contributors: $total_contributors"
echo "Output CSV: $output_csv"
