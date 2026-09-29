# Changelog

All notable changes to this code-only packaging are documented here. This log describes repository organization; it does not revise the published article.

## 1.0.0 — 2026-09-30

### Added

- Independent, privacy-screened repository structure for the publisher-supplied Stata and R analysis code.
- Portable section-level Stata wrappers and a top-level curated orchestrator.
- Explicit `smoke` and `paper` resampling profiles with a recorded random seed; `paper` is the default.
- Portable R entry point and retained `renv` environment metadata.
- Data-availability, replication, code-audit, exhibit-map, citation, and rights documentation.
- Empty, ignored placeholders for local input and output directories.
- Automated release checks intended to reject data, archives, logs, workstation paths, and common secret patterns.
- Upstream installation and preflight for third-party Stata dependencies, which are not vendored in the public tree.
- Preserved the MIT notice for the vendored `renv` activation bootstrap.

### Changed

- Centralized repository and output path handling to reduce workstation-specific edits.
- Kept the public workflow on `runGPS = 0` because restricted GPS inputs are not distributed.
- Separated source code from locally generated results and logs.
- Removed the raw-data construction route from the public package after review found record-specific correction literals and verbatim responses in that source tree.

### Excluded

- All research data and source archives.
- The historical raw-data construction tree, because source literals included record identifiers and verbatim responses.
- Restricted coordinates and geographic identifiers.
- Generated tables, figures, intermediate datasets, and execution logs.
- Manual GIS source materials and exhibits.

### Validation status

- Static organization and privacy-oriented release checks were performed.
- A complete clean-machine run from authorized prepared analysis inputs through every available scripted exhibit was not performed.
