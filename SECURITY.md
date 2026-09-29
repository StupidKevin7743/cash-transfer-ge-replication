# Security and responsible disclosure

This repository is a code-only replication package. It must not contain raw or
derived research data, direct or indirect identifiers, restricted geographic
information, machine-local paths, credentials, execution logs, archives, or
generated results.

## Report a suspected disclosure privately

If you believe protected information or a credential appears in this
repository, do not quote it, download it further, or describe it in a public
issue. Use **Security > Report a vulnerability** on the GitHub repository to
send a private report. If private reporting is unavailable, contact the
repository owner through their GitHub profile without including the suspected
content in a public message.

Include only the minimum information needed to locate the problem: the file
path, commit identifier, and a high-level description. Do not attach a copy of
the suspected data.

## Release controls

Every proposed change is checked by `tools/validate_release.py`. The audit
rejects sensitive data and archive formats, generated outputs, local workspace
references in executable source, likely credentials, symbolic links, and files
larger than 10 MiB. It also verifies that restricted GPS analysis remains
disabled. The check is defense in depth and does not replace human review of
every release diff.

Only the current default branch is maintained. This policy concerns the
replication package itself; questions about the underlying study or access to
research data belong with the original data distributor.
