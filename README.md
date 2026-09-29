# General Equilibrium Effects of Cash Transfers: Analysis-Code Replication Package

This repository is a privacy-screened, code-only packaging of the replication materials for:

> Egger, Dennis, Johannes Haushofer, Edward Miguel, Paul Niehaus, and Michael Walker. 2022. “General Equilibrium Effects of Cash Transfers: Experimental Evidence From Kenya.” *Econometrica* 90 (6): 2603–2643. <https://doi.org/10.3982/ECTA17945>.

The repository is an independent preservation and organization effort based on the code distributed with the publisher’s supporting information. It is **not** an official repository of the article’s authors or publisher.

## Important scope statement

- No research data, microdata, geographic coordinates, logs, or generated results are distributed here.
- Raw-data construction programs are also excluded because the historical source embeds record identifiers and verbatim responses in correction and recoding statements. This release begins from authorized, disclosure-reviewed analysis inputs.
- Restricted GPS inputs are absent. The checked-in configuration sets `runGPS = 0`; analyses therefore use the public-package clustered standard-error path and may not match the article’s spatial HAC standard errors.
- Some exhibits require inputs or manual GIS work that are not part of this code-only release.
- A complete clean-machine, end-to-end execution has not been verified for this release. The repository has been statically reviewed and organized, but statistical equivalence to every published number is not certified.

Read [DATA_AVAILABILITY.md](DATA_AVAILABILITY.md) before obtaining or placing any data in the repository, and read [REPLICATION.md](REPLICATION.md) before running the code.

## Repository contents

| Path | Purpose |
|---|---|
| `ge_analysis.do` | Original-style master Stata entry point for tables, figures, and in-text statistics. |
| `run_all.do` | Curated public-code workflow using section-specific wrappers. |
| `run_figures.R` | Portable R entry point for the R-generated figures. |
| `config.do` | Reproduction mode and random-seed configuration. |
| `do/analysis/` | Stata and R analysis programs. |
| `do/programs/` | Shared Stata programs. |
| `scripts/` | Portable analysis wrappers and dependency setup. |
| `ado/` | Project-specific Stata helper commands retained from the source package. |
| `renv.lock`, `renv/` | R dependency snapshot and activation support. |
| `LICENSES/` | License notices for vendored third-party bootstrap code. |
| `data/`, `rawdata/` | Empty, ignored locations for authorized prepared data and auxiliary inputs. |
| `outputs/` | Empty, ignored destination for local generated results. |
| `docs/` | Code-audit notes and the exhibit-to-code map. |

## Software

The upstream materials specify Stata 15 or later and R 4.1.3. Later versions may work, but should be treated as a separate computational environment and documented in any replication report.

The full Stata masters use the community-contributed `project` command, and several analyses use other community-contributed commands. Third-party Stata packages are not vendored in this repository. Run the dependency installer and preflight supplied with this release:

```stata
do scripts/install_stata_dependencies.do
do scripts/preflight.do
```

For R, restore the recorded environment from the repository root:

```r
install.packages("renv")
renv::restore()
```

The installer retrieves current Stata package versions and therefore is not a version lock. The R lockfile records package versions more precisely, but availability of archived package binaries can vary by operating system and date. Neither environment has been fully verified on a clean machine for this release.

## Data setup

Obtain any data only from an authorized source and under the applicable access and redistribution terms. The article’s publisher page links the supporting information: <https://onlinelibrary.wiley.com/doi/10.3982/ECTA17945>.

Place provider-supplied, disclosure-reviewed analysis files under `data/` and any auxiliary inputs read directly by the analysis under `rawdata/`, preserving the filenames referenced by the code. Do not commit those files. The repository deliberately ignores both directories except for their explanatory `README.md` files.

## Running the curated workflow

Start Stata from the repository root. The default `paper` mode uses the paper-scale resampling counts. For a short code-flow check, explicitly select `smoke`; smoke mode is **not** suitable for comparing inferential results with the article.

```stata
global REPLICATION_MODE "smoke"
global REPLICATION_SEED 20220930
do run_all.do
```

For the default paper-scale resampling counts:

```stata
global REPLICATION_MODE "paper"
global REPLICATION_SEED 20220930
do run_all.do
```

Paper mode can be computationally expensive. The curated wrappers write generated files below `outputs/`, including section-specific intermediates under `outputs/<section>/temp/`. The legacy `ge_analysis.do` route retains the historical root-level `temp/` layout.

To generate the two R figures after their Stata prerequisites exist:

```sh
Rscript run_figures.R
```

## Running the original-style analysis master

The full analysis master preserves the upstream `project` workflow:

```stata
ssc install project
project, setup
do ge_analysis.do
```

This route expects the full set of authorized prepared analysis inputs. It may stop where restricted, unavailable, or manually generated inputs are required. Raw-data construction is deliberately outside this public repository, so this route must not be interpreted as a one-command reconstruction from survey extracts.

## Reproducibility expectations

Three distinct outcomes should not be conflated:

1. **Code-flow check:** explicitly selected `smoke` mode tests whether available inputs and major program paths can execute.
2. **Paper-scale computation:** `paper` mode restores the intended large resampling counts, but does not restore restricted GPS inputs.
3. **Published-number replication:** requires the appropriate prepared data, software environment, restricted spatial inputs where applicable, and manual exhibit inputs. This repository alone cannot certify that outcome.

The detailed mapping from published exhibits to source files is in [docs/EXHIBIT_MAP.md](docs/EXHIBIT_MAP.md). Known audit findings are in [docs/CODE_AUDIT.md](docs/CODE_AUDIT.md).

## Citation and rights

Please cite the published article, not this repository as a substitute for the research contribution. Machine-readable citation metadata are provided in [CITATION.cff](CITATION.cff).

No blanket open-source license is asserted for the upstream research code. Third-party Stata dependencies retain their own licenses and are installed separately; the included `renv` bootstrap retains its MIT license. See [NOTICE.md](NOTICE.md), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), and [LICENSES/renv-MIT.txt](LICENSES/renv-MIT.txt) before reuse or redistribution.

## Privacy and responsible use

Never commit individual-level data, household or enterprise identifiers, precise locations, restricted GPS material, credentials, logs containing record-level output, or generated files derived from restricted inputs. If an input’s disclosure status is uncertain, keep it outside version control and consult the data provider.
