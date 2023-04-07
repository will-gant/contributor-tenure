# Git Contributor Turnover Calculator

Hacked together bash script to calculate contributor turnover on git projects. Generates a CSV file with the dates of the first and last commits by each ex-contributor to a git repo (anyone who hasn't committed in the last 90 days), along with the difference between those dates in days. Also outputs an overall average for the repo.

## Prerequisites
* Bash 4.0.0 or later (uses associative arrays)
* Git (version 2.x)
* [yq](https://mikefarah.gitbook.io/yq/) (version 4.x)

## Manual Preparation

Because engineers are tricksy and like to change the email and name in their local git config at random intervals - and therefore any analysis that doesn't take account of that is massively unreliable - this script depends on a human first manually putting together a yaml file like this:

```yaml
emails:
  108812733+j-bloggs@users.noreply.github.com: Joe Bloggs
  joe_bloggs@gmail.com: Joe Bloggs
  doej@example.com: Jane Doe
  jane.doe@softwareconsultancy.com: Jane Doe
names:
  Joe Bloggs: Joe Bloggs
  jd: Jane Doe
  Jane: Jane Doe
```

This is a mapping of the names and email addresses that appear in a git commit to a person's _real_ name (or any other unique identifier - if you're pretty sure names/emails relate to the same person, it's better to map them to _something_ than nothing). When trying to identify a contributor, the script first checks to see if their committer email maps to an email in the yaml config. If it doesn't, the script then checks to see if the committer's name maps. If neither do, we skip that contributor and they're excluded from the average turnover we calculate at the end.

## Running the Script

Execute the script, passing either an absolute path to your repo, or one relative to your current working directory.

```console
$ ./git_contributor_commit_days_calculator.sh REPO_PATH [CONFIG_PATH] [OUTPUT_PATH]
```

The script also takes two optional arguments: paths to your YAML configuration file and the path where you'd like the script to generate its output CSV file. If not provided, the default names are `git_contributors.yaml` and `git_contributors.csv`, and it's assumed both should be in your current working directory.

The generated CSV has one row per identified contributor and  four columns: Name, First Commit, Last Commit, and Commit Days
