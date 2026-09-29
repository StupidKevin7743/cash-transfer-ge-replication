# Code Audit and Release Assessment

## Audit objective

The audit assessed whether the available code could be organized as a professional, code-only scholarly replication repository without distributing research data or restricted material. It also reviewed entry points, dependency declarations, path handling, stochastic settings, output routing, and the relationship between programs and published exhibits.

This was a static code and release-structure audit. It was not a statistical reanalysis, disclosure review of the underlying datasets, or complete clean-machine execution.

## Audited code inventory

At the final release-candidate audit, the packaged code tree contained:

- 73 Stata `.do` files under `do/`;
- 14 Stata wrapper and setup `.do` files under `scripts/`;
- 2 top-level Stata analysis entry points (`run_all.do` and `ge_analysis.do`), plus `config.do`;
- 2 substantive R figure scripts under `do/`, plus top-level compatibility/runner code;
- 6 project-specific Stata `.ado` files under `ado/`;
- an R dependency lockfile and `renv` activation metadata.

The script count includes the release-specific installer and preflight; the repository also contains documentation, configuration, environment metadata, and the release validator.

## Release decisions

### Code only

The public repository is restricted to analysis/program code, documentation, environment metadata, and empty directory placeholders. Data files, archives, raw-data construction code containing embedded record-level material, generated results, intermediate files, and execution logs are outside the release boundary.

### Independent status

The repository is described as an independent packaging of code from the publisher’s supporting information. It does not claim to be the original authors’ official repository and does not claim endorsement.

### No blanket license

The source materials used for packaging did not provide a top-level license covering all research code. No new blanket license was invented, and third-party Stata packages are installed from upstream rather than vendored. `NOTICE.md` and `THIRD_PARTY_NOTICES.md` state the resulting rights position.

### Restricted spatial inputs

The public code setting remains `runGPS = 0`. Restricted GPS inputs are not supplied. This preserves the disclosure boundary but changes applicable inference from spatial HAC to clustered standard errors, so published inferential statistics need not match.

## Findings and mitigations

| Area | Finding | Release treatment |
|---|---|---|
| Data confidentiality | Empirical code expects household, enterprise, treatment, market, and spatial data. | No data are included; input directories are ignored and documented. |
| Embedded record material | Historical construction programs contain identifiers and verbatim open-ended responses in executable and commented source. | The entire `do/construct/` tree and construction master are excluded. |
| Geographic confidentiality | Restricted GPS inputs needed for the article’s spatial-HAC path are unavailable for public distribution. | `runGPS = 0`; the expected inferential difference is disclosed prominently. |
| Workstation paths | Historical code and runners relied on working-directory assumptions or IDE context. | Repository/output roots are centralized; R receives a portable command-line entry point. |
| Computation time | Upstream convenience settings used only 3 resampling repetitions in several places, while paper-scale settings were 2,000/500/200. | Explicit `smoke` and `paper` profiles make the distinction visible; paper mode is the default and documentation rejects smoke-mode inference. |
| Randomness | Several stochastic paths depended on ambient random-number state. | A repository-level seed is exposed and should be recorded for every run. |
| Error visibility | Some convenience runners historically continued after a failed component. | Release wrappers are intended to preserve the first nonzero return code and fail the run visibly. |
| Dependencies | Community Stata commands are external; R packages are recorded in `renv.lock`. | Third-party Stata code is not vendored; dependency notes, an installer, and a preflight are provided. |
| Record-specific corrections | Historical construction code embedded correction values tied to individual records. | The construction tree is withheld; any reconstruction must remain under custodian controls. |
| Exhibit completeness | Several GIS exhibits and manually assembled items are outside the executable source tree. | `EXHIBIT_MAP.md` identifies them as manual or unavailable. |
| Full-run evidence | The available environment did not support a complete, authorized-data clean run. | The release makes no end-to-end or exact-numerical certification claim. |

## Reproducibility risks that remain

1. **Input-version ambiguity.** The code assumes specific schemas and filenames. Inputs obtained from a later or differently processed archive may not be compatible.
2. **Dependency drift.** The installer retrieves current Stata packages, and SSC commands or R package archives can change or disappear. The R lockfile helps, but Stata dependencies are not comprehensively version-pinned.
3. **Software-version sensitivity.** Random-number streams, sorting, graphics, numerical optimization, and exported formatting can differ across Stata, R, operating-system, and font versions.
4. **Restricted-inference gap.** Without GPS inputs, spatial-HAC standard errors cannot be regenerated from this package.
5. **Manual production steps.** GIS exhibits and manually assembled lists do not have a complete scripted provenance in the available tree.
6. **Compute burden.** Paper-scale bootstrap and randomization-inference settings can require substantial memory and wall time.
7. **Analysis-only boundary.** The curated wrappers prioritize major public analysis paths and are not a substitute for the withheld raw-data construction workflow.
8. **Custodian preprocessing.** Any reconstruction from affected raw inputs requires disclosure-reviewed preprocessing that is intentionally outside this repository.

## Validation completed for the release

The release process includes checks for:

- forbidden data, archive, document, database, and log extensions;
- symbolic links and unexpectedly large files;
- common credentials and secret patterns;
- workstation-specific absolute paths;
- the required `runGPS = 0` public setting;
- required documentation and entry points;
- accidental tracked content inside the data and output directories.
- accidental reintroduction of the excluded raw-construction tree or vendored SSC snapshot.

These checks reduce accidental disclosure risk but cannot prove that arbitrary source-code comments or generated outputs contain no sensitive information. Human review remains necessary.

## Interpretation of a successful run

A successful `smoke` run shows only that the tested paths executed with the supplied inputs. A successful `paper` run shows that paper-scale resampling settings were requested. Neither automatically establishes exact reproduction of the article because restricted inference, software versions, prepared-input provenance, and manual exhibits still matter.

Any public replication report should separate:

- exact matches;
- differences expected from clustered versus spatial-HAC inference;
- differences caused by software or dependency versions;
- unavailable/manual exhibits;
- unexpected discrepancies requiring substantive investigation.
