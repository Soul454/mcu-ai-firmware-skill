# Git and Release

## Decide hosting first

Before creating a repository, ask: personal account, company server, or both?
Default to **private** for company/customer work. Only publish to a public
repository after explicit confirmation and sanitization.

## Credentials

- Prefer SSH keys for git access.
- Never commit tokens, passwords, private keys, provisioning files or `.env`.
- Never write credentials into source "for now". If a credential is already in
  history, flag it, rotate it, and consider rewriting history after rotation.
- Do not echo secrets in logs; redact when reporting command output.

## Repository hygiene

- `.gitignore`: build outputs, toolchain binaries, generated assets, IDE files,
  packaging artifacts, local caches.
- One repository per product/tool; keep a separate repo for reusable skills,
  templates and demo projects.
- Keep a clear `README.md`: what it is, how to build, how to run tests, how to
  flash, and the hardware prerequisites.
- Tag releases; keep release notes short and factual (versions, changes,
  migration steps, known issues).

## Branching and commits

- Work on a branch; keep `main` buildable.
- Commit messages: one-line subject (what + why), body with evidence and risk.
- Rebase before push when the remote moved; resolve binary artifact conflicts by
  rebuilding rather than merging.
- Don't force-push shared branches without asking.

## Release checklist

1. `make ci` (or equivalent) green from a clean tree.
2. Version numbers bumped in every place they are duplicated (app, installer,
   docs) — search for them.
3. Release artifacts built from the tagged commit.
4. Smoke test the packaged artifact (install → run → core path → uninstall).
5. Sanitization pass before publishing externally:
   - customer/project names, internal hosts and IPs, credentials, device IDs,
     screenshots with live data, proprietary protocol constants;
   - commit history, not just the working tree.
6. Record the artifact hash/size and where it was published.

## Sharing a skill or template repo

- Genericize all examples; replace real identifiers with placeholders.
- Include a license (MIT/Apache-2.0) and a short usage/installation section.
- State prerequisites and limitations explicitly.
- Tag a version so downstream users can pin it.
