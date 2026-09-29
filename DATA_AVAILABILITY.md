# Data Availability and Confidentiality

## No data are distributed

This repository contains code and documentation only. It does not distribute research microdata, geographic coordinates, source archives, intermediate datasets, logs, or generated results.

The empty `rawdata/` and `data/` directories exist solely to document the directory layout expected by the programs. Their contents are ignored by version control, apart from the local explanatory `README.md` files.

## Authorized source

The publisher’s article page links the supporting information for the study:

- Article and supporting information: <https://onlinelibrary.wiley.com/doi/10.3982/ECTA17945>
- DOI record: <https://doi.org/10.3982/ECTA17945>

Access, use, and redistribution are governed by the provider’s current terms and any documentation accompanying the files. A filename containing words such as `PUBLIC` is not, by itself, sufficient evidence that unrestricted redistribution is permitted. Users are responsible for confirming their authorization and complying with ethical, contractual, and legal restrictions.

## Local placement

After obtaining authorized, disclosure-reviewed inputs:

1. Put provider-supplied analysis files in `data/`.
2. Put only auxiliary inputs read directly by analysis programs in `rawdata/`.
3. Preserve the filenames and relative paths referenced by the Stata programs.
4. Keep archives outside the repository or delete local copies after extraction if permitted by the provider’s terms.
5. Before pushing, inspect `git status --short` and `git diff --cached --name-only`, then run the release validator against a clean, data-free release tree.

The legacy analysis master creates intermediates below the root-level `temp/` directory. Curated wrappers create section-specific intermediates below `outputs/<section>/temp/`. All generated files remain local and must not be committed.

## Why construction code is not included

The historical raw-data construction programs contain record-specific identifiers and verbatim open-ended responses in correction, diagnostic, and recoding statements. Some appear inside comments but would still be disclosed by publication. The public release therefore excludes the entire raw-data construction tree and begins from prepared analysis files. This is a privacy boundary, not a claim that the omitted programs are unnecessary for provenance.

An authorized reconstruction from raw inputs must be conducted under the data custodian's controls using disclosure-reviewed preprocessing code. The omitted record identifiers, response text, and corrections must not be restored to this public repository.

## Restricted geography and inference

The public code path does not include restricted GPS inputs. `do/global_runGPS.do` therefore sets:

```stata
global runGPS = 0
```

With that setting, applicable analyses use clustered standard errors rather than the spatial HAC standard errors used for the article’s restricted-coordinate specification. Point estimates may remain comparable when the underlying analysis data are identical, but standard errors, p-values, confidence intervals, and significance markers can differ. This is an intentional disclosure limitation, not evidence of a computational failure.

## Inputs not supplied by this repository

The code references multiple prepared Stata datasets and auxiliary inputs, including household, enterprise, treatment-timing, market-price, and spatial-buffer files. This document does not assert that every referenced input is publicly downloadable or redistributable.

Several study-area figures were produced manually with GIS software and require spatial source material that is not included. See [docs/EXHIBIT_MAP.md](docs/EXHIBIT_MAP.md).

## Disclosure checklist

Before sharing any locally generated artifact, verify that it contains none of the following:

- direct personal or business identifiers;
- free-text fields that can reveal identity;
- household, respondent, enterprise, or enumerator keys;
- exact coordinates or fine-grained geographic identifiers;
- small-cell output that creates re-identification risk;
- credentials, workstation paths, or access tokens;
- record-level data or logs generated from restricted inputs.

When in doubt, do not distribute the artifact. Consult the data provider or the relevant institutional data-governance process.
