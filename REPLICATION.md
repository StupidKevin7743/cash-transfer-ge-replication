# Replication Guide

## 1. What this package can establish

This package preserves and organizes the available Stata and R analysis code for the article. It supports code inspection, environment reconstruction, and authorized local execution from prepared analysis inputs. It does not contain the data required to reproduce estimates, and a complete clean-machine run has not been verified for this release.

Successful execution of a subset of scripts is not, by itself, proof that all published results have been reproduced. Record the software versions, input provenance, configuration, random seed, warnings, and output checksums used in any formal replication report.

## 2. Directory contract

Run commands from the repository root.

| Directory | Role | Version-control policy |
|---|---|---|
| `rawdata/` | Authorized source inputs | Never commit data |
| `data/` | Authorized, disclosure-reviewed analysis files | Never commit data |
| `temp/` | Legacy-master intermediates | Never commit |
| `outputs/` | Curated-wrapper results, logs, and section-specific `temp/` intermediates | Never commit generated content |
| `do/` | Analysis and shared Stata programs | Tracked |
| `scripts/` | Portable wrappers and setup utilities | Tracked |
| `ado/` | Project-specific Stata helper commands | Tracked, subject to upstream rights |

The wrapper scripts define `REPO_ROOT` for source inputs and `RUN_ROOT` for generated section-specific files. Avoid editing source programs merely to insert a workstation-specific path.

## 3. Software setup

### Stata

The upstream documentation specifies Stata 15 or later. Third-party Stata packages are not vendored in this repository, and the installer retrieves current upstream versions rather than a version-pinned environment. From Stata, install required community commands and then run the preflight:

```stata
do scripts/install_stata_dependencies.do
do scripts/preflight.do
```

The original-style master files require `project`; the installer should retrieve it, but it can also be installed directly:

```stata
ssc install project
```

Review [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) before redistributing any third-party dependency.

### R

The recorded reference version is R 4.1.3. From the repository root:

```r
install.packages("renv")
renv::restore()
```

Do not update the lockfile during a replication run unless the purpose is explicitly to test a new environment. If packages cannot be restored, document the unavailable package/version and the substitution used.

## 4. Configure computation

`config.do` supports two execution profiles:

| Mode | Purpose | Multiplier bootstrap | Randomization inference | BIC split sample |
|---|---|---:|---:|---:|
| `smoke` | Explicit smoke testing and debugging | 3 | 3 | 3 |
| `paper` | Default paper-scale resampling settings | 2,000 | 500 | 200 |

Set a mode and seed before launching a Stata workflow:

```stata
global REPLICATION_MODE "smoke"
global REPLICATION_SEED 20220930
```

The repository seed initializes stochastic paths that do not set a seed internally. Several historical routines retain their own fixed seeds. Record both the repository configuration and any script-level seed when evaluating reproducibility; cross-version bitwise identity is not guaranteed.

If `REPLICATION_MODE` is unset, the code defaults to `paper`. The aliases `fast` and `quick` are accepted for backward compatibility and normalized to `smoke`. Use smoke mode only to test code flow. Its p-values and confidence intervals are not meaningful substitutes for paper-scale computation.

## 5. Prepared-input boundary

The historical raw-data construction tree is not part of this release. Static review found record-specific identifiers and verbatim open-ended survey responses embedded in correction, diagnostic, and recoding statements, including commented blocks. Publishing that tree would therefore disclose data values even without publishing a dataset.

Use only analysis files obtained from an authorized provider and already cleared for the intended use. The section wrappers check for key prepared inputs and fail rather than silently rebuilding them. Important prerequisites include `data/GE_HHIndividualWageProfits_ECMA.dta`, `data/Ent_ML_SpatialData_long_FINAL.dta`, `data/HH_ENT_Multiplier_Dataset_ECMA.dta`, and `data/GE_Enterprise_BL_ECMA.dta`. This list is not exhaustive; individual analysis modules reference additional provider-supplied files.

Do not restore the omitted construction programs to this repository. Any future public construction release requires a separate disclosure review and a refactor that moves identifiers and raw-text coding into a custodian-controlled preprocessing stage.

## 6. Choose an execution route

### Route A: curated public-code workflow

With authorized inputs in place:

```stata
do run_all.do
```

After the dependency preflight, the orchestrator calls six section-specific workflows in this order:

1. household expenditure, input, and supporting outputs;
2. additional labor/input outcomes;
3. price outputs;
4. multiplier outputs;
5. marginal propensity to consume;
6. enterprise outputs.

Each wrapper writes to a section-specific subdirectory below `outputs/`. A nonzero return code should be treated as a failed run even if earlier outputs exist.

### Route B: full original-style analysis

After placing all expected prepared analysis files:

```stata
project, setup
do ge_analysis.do
```

This legacy `project` route maps the available programs to the main tables, appendix exhibits, and in-text statistics. It retains the historical root-level `results/`, `logs/`, and `temp/` layout, whereas the curated wrappers route generated work below `outputs/`. Manual GIS exhibits remain outside the executable workflow.

### R figures

After the corresponding Stata multiplier and price-product intermediates exist:

```sh
Rscript run_figures.R
```

The R entry point runs the main multiplier figure and the product-level price-effects figure. Missing prerequisites should be treated as a data-pipeline issue, not repaired by inserting fabricated inputs.

## 7. Expected limitations

- **No input data:** all empirical execution depends on separately obtained, authorized inputs.
- **No raw-data construction code:** the historical construction tree is withheld because code literals themselves contained record-level material.
- **No restricted GPS:** `runGPS = 0` selects clustered rather than spatial HAC standard errors where applicable.
- **Manual exhibits:** some maps and lists were created outside the scripted workflow.
- **External Stata commands:** availability and behavior can change across command versions.
- **Historical R environment:** archived packages may not restore identically on current systems.
- **High compute cost:** paper-scale bootstrap and randomization-inference settings can take substantial time.
- **No end-to-end certification:** this release has not been run completely from authorized prepared analysis inputs through every available scripted exhibit on a clean machine.

## 8. Validation protocol

For a defensible replication record:

1. Record the Git commit hash.
2. Record Stata, R, operating-system, and dependency versions.
3. Record the source and checksums of every authorized input without publishing restricted files.
4. Run the release validator on a clean, data-free release tree or fresh checkout before publication or pushing. It is expected to fail in a working copy that contains local inputs or generated artifacts.
5. Save console exit codes and retain logs securely; do not commit logs containing sensitive output.
6. Compare output structure, sample sizes, coefficients, standard errors, and resampling settings—not only rendered appearance.
7. Explain every discrepancy, including the expected standard-error differences caused by `runGPS = 0`.
8. Keep a separate manifest of manual or unavailable exhibits.

## 9. Troubleshooting order

When a script fails, check in this order:

1. the current working directory is the repository root;
2. the required input file exists at the exact referenced relative path;
3. the input came from an authorized and compatible version of the supplement;
4. required Stata commands or R packages are installed and their actual versions are recorded;
5. `REPLICATION_MODE`, `REPLICATION_SEED`, and `runGPS` are recorded;
6. prerequisite analysis modules and prepared intermediates are present;
7. the first nonzero return code in the log, rather than later cascade errors.

Do not resolve a missing restricted input by weakening privacy controls or committing confidential material.
