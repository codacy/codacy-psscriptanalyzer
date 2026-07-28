# Codacy-Psscriptanalyzer Docker Container

[![Codacy Badge](https://api.codacy.com/project/badge/Grade/8a05c207b252459fb5caef7d9dc922c0)](https://www.codacy.com/gh/codacy/codacy-psscriptanalyzer?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=codacy/codacy-psscriptanalyzer&amp;utm_campaign=Badge_Grade)
[![Build Status](https://circleci.com/gh/codacy/codacy-psscriptanalyzer.svg?style=shield&circle-token=:circle-token)](https://circleci.com/gh/codacy/codacy-psscriptanalyzer)
[![Docker Version](https://images.microbadger.com/badges/version/codacy/codacy-psscriptanalyzer.svg)](https://microbadger.com/images/codacy/codacy-psscriptanalyzer "Get your own version badge on microbadger.com")

[Docker](https://www.docker.com) container to allow support for [psscriptanalyzer](https://github.com/PowerShell/PSScriptAnalyzer) on Codacy.

## Dockerfile building

To build the Codacy-psscriptanalyzer dockerfile : 

1. Clone the source:

    ``` sh
	$ git clone https://github.com/codacy/codacy-psscriptanalyzer.git
	$ cd codacy-psscriptanalyzer
    ```

2. Build the container:

    ``` sh
    $ docker build -f Dockerfile -t codacy-psscriptanalyzer .
    ```

## Docs

[Tool Developer Guide](https://support.codacy.com/hc/en-us/articles/207994725-Tool-Developer-Guide)

[Tool Developer Guide - Using Scala](https://support.codacy.com/hc/en-us/articles/207280379-Tool-Developer-Guide-Using-Scala)

## Test

We use the [codacy-plugins-test](https://github.com/codacy/codacy-plugins-test) to test our external tools integration.
You can follow the instructions there to make sure your tool is working as expected.

## Agent Playbook: Updating This Repository End-to-End

This section is written for an AI coding agent (or a human) tasked with updating this repo — most commonly bumping the wrapped PSScriptAnalyzer module version, but also base image / CircleCI orb bumps. Follow it top to bottom; it tells you what to change, how to regenerate derived files, how to test locally, and how to interpret CI so you can iterate on failures without guessing.

### 1. What this repository is

This is a **Codacy engine**: a thin PowerShell wrapper (`runTool.ps1`) that packages the [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) PowerShell module as a Docker image Codacy's platform can run against a customer's PowerShell source code. There is no Scala/JVM build here — the whole engine is plain PowerShell (`pwsh`) running on the official `mcr.microsoft.com/powershell` base image. The `docs/` directory is not just documentation — it is **machine-consumed configuration**:

- `docs/patterns.json` — the full list of PSScriptAnalyzer rules ("patterns") Codacy knows about, their severity/category, and which are enabled out of the box. Generated file, do not hand-edit.
- `docs/description/description.json` + `docs/description/*.md` — human-readable titles/descriptions per pattern, used in the Codacy UI. Generated file, do not hand-edit (each `.md` is copied verbatim from the upstream PSScriptAnalyzer repo's own rule docs).
- `docs/tests/*.ps1` and `docs/multiple-tests/*` — fixtures used by `codacy-plugins-test` to validate the engine actually produces the results it claims to for real PowerShell code samples.
- `docs/tool-description.md` — short blurb about the tool, hand-maintained.

Both generated artifacts above come from **`install.ps1`** (driven by `scripts/generateDocs.sh`), which downloads the upstream `PowerShell/PSScriptAnalyzer` source tarball for the pinned version, installs that exact module version locally via `Install-Module`, runs `Get-ScriptAnalyzerRule` against it, and cross-references each rule against the downloaded source's `docs/Rules/*.md` files to build `docs/patterns.json` and `docs/description/*`. This means the generator needs **network access**, `pwsh` (PowerShell 7), `wget`/`tar`, and the `PSScriptAnalyzer` PowerShell module installed.

### 2. Files that encode versions — check all of these on every update

| File | What it controls | What to check |
|---|---|---|
| `psscriptanalyzer.version` | The exact PSScriptAnalyzer module version installed in the image and used to regenerate docs | Bump to the target version; this is the single source of truth other files/scripts read from. |
| `Dockerfile` → `Install-Module PSScriptAnalyzer -RequiredVersion $(...)` | Reads `psscriptanalyzer.version` at build time — no separate literal to edit | Confirm it still reads from the file (do not hardcode a version here). |
| `Dockerfile` → base image (`mcr.microsoft.com/powershell:lts-7.4-alpine-3.17`) | PowerShell runtime the engine runs on | Only bump if the new PSScriptAnalyzer version raises its minimum PowerShell requirement, or a newer LTS/Alpine tag is available. |
| `.circleci/config.yml` → `codacy/base` orb | Shared CircleCI steps (checkout, versioning, shell jobs) | Check the latest published version on the CircleCI orb registry. |
| `.circleci/config.yml` → `codacy/plugins-test` orb | Runs `codacy-plugins-test` in CI | Same as above. |

### 3. Step-by-step update procedure

1. **Bump `psscriptanalyzer.version`** to the target release (confirm a matching module version exists on the [PowerShell Gallery](https://www.powershellgallery.com/packages/PSScriptAnalyzer) and a matching tag/tarball exists at `https://github.com/PowerShell/PSScriptAnalyzer/archive/<version>.tar.gz`, since `scripts/generateDocs.sh` downloads exactly that URL).
2. **Regenerate the docs**: run `scripts/generateDocs.sh` (requires `pwsh`, `wget`, `tar`, network access). This downloads the new PSScriptAnalyzer source, installs the matching module version, and re-runs `install.ps1`, which rewrites `docs/patterns.json` and `docs/description/*`. Review the diff carefully for new/removed/renamed rules — new rules typically land with `enabled: false` unless deliberately added to the `$enabledRules` list in `install.ps1`, and removed rules will leave stale `docs/description/*.md` files that should be deleted.
3. **Build the Docker image**: `docker build -f Dockerfile -t codacy-psscriptanalyzer .` — this step alone will fail fast if `Install-Module PSScriptAnalyzer -RequiredVersion <version>` can't resolve, which is a quick sanity check that the version string is valid.
4. **Run `codacy-plugins-test` locally** before pushing — clone https://github.com/codacy/codacy-plugins-test and run its Docker-based test commands (including the multiple-tests suite, since CI runs `run_multiple_tests: true`) against your locally built image tag.
5. **Iterate on failures**, re-running only the relevant test command after each fix.
6. **Commit** the version bump together with the regenerated `docs/patterns.json` and `docs/description/*` files in one change.
7. **Push and open a PR.**
8. **Poll the PR's real CI checks until they all pass — local validation is NOT the finish line.** After every push, run `gh pr checks <pr-url>` and keep re-polling (short sleep while any check is `pending`) until all checks finish. If a check fails, fetch its actual log (don't guess), find the true root cause, fix it, push again (never `--no-verify`, never force-push), and re-poll. Repeat until every check is green. **The CI environment's toolchain can differ from your local one**, so a clean local run does not guarantee CI passes. Only stop iterating when every check passes, or you hit a genuine product/infra decision that needs a human.

### 4. Common failure modes and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| `docker build` fails on `Install-Module PSScriptAnalyzer -RequiredVersion ...` | The version string in `psscriptanalyzer.version` doesn't exist on the PowerShell Gallery, or has a typo/trailing newline | Verify the exact version on the PowerShell Gallery; keep the file content newline-free (existing file has no trailing newline). |
| `scripts/generateDocs.sh` fails to download the tarball | The GitHub release tag doesn't match the module version exactly (PSScriptAnalyzer tags are usually just the version number, e.g. `1.24.0`) | Check the actual tag name on `PowerShell/PSScriptAnalyzer` releases and adjust if the tagging convention changed. |
| A pattern's title/description in `docs/description/*.md` is missing or falls back to the raw rule id | `install.ps1`'s `getTitleFromRuleFile`/`getTitle` couldn't match the rule to a source file in `PSScriptAnalyzer/Rules/*` (script prints `UNMATCHED PATTERNS: <n>` and lists each one) | Inspect the unmatched rule names against the downloaded `PSScriptAnalyzer/Rules/` and `PSScriptAnalyzer/docs/Rules/` directory structure — naming conventions occasionally change between versions. |
| New security-sensitive rule ships disabled by default | `install.ps1` only auto-enables rules listed in its hardcoded `$enabledRules` array (and assigns Security subcategories via `$visibilityRules`/`$cryptoRules`/`$commandInjectionRules`/`$authRules`) | Decide deliberately whether the new rule should be added to those arrays; don't assume regeneration alone gets it right. |

### 5. Definition of done

- `psscriptanalyzer.version` bumped, and it matches a real PowerShell Gallery release and a real upstream GitHub tag/tarball.
- `docs/patterns.json` and `docs/description/*` regenerated via `scripts/generateDocs.sh`/`install.ps1`, with new/removed rules reviewed by hand (not blindly committed).
- `docker build -f Dockerfile -t codacy-psscriptanalyzer .` succeeds.
- `codacy-plugins-test` commands (including the multiple-tests suite) pass locally against the freshly built image.
- **After pushing and opening/updating the PR, every CI check on it is green.** Poll `gh pr checks <pr-url>` and iterate on any failure until all pass.

## What is Codacy

[Codacy](https://www.codacy.com/) is an Automated Code Review Tool that monitors your technical debt, helps you improve your code quality, teaches best practices to your developers, and helps you save time in Code Reviews.

### Among Codacy’s features

- Identify new Static Analysis issues
- Commit and Pull Request Analysis with GitHub, BitBucket/Stash, GitLab (and also direct git repositories)
- Auto-comments on Commits and Pull Requests
- Integrations with Slack, HipChat, Jira, YouTrack
- Track issues in Code Style, Security, Error Proneness, Performance, Unused Code and other categories

Codacy also helps keep track of Code Coverage, Code Duplication, and Code Complexity.

Codacy supports PHP, Python, Ruby, Java, JavaScript, and Scala, among others.

### Free for Open Source

Codacy is free for Open Source projects.