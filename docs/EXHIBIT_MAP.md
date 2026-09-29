# Published Exhibit-to-Code Map

This map identifies the source program associated with each published exhibit in the available master analysis. A listed program indicates a code path, not a verified reproduction. Data prerequisites are not distributed, and several exhibits were produced manually or with unavailable spatial inputs.

## Main text

| Exhibit | Source program | Notes |
|---|---|---|
| Figure 1 | `do/analysis/multiplier/Figure1_Multiplier.R` | Requires multiplier intermediates produced by the Stata multiplier sequence. |
| Table 1 | `do/analysis/main/Table1_B8_F3_ExpSavingsIncome.do` | Also produces Table B.8 and Table F.3 material. |
| Table 2 | `do/analysis/main/Table2_InputPricesQuantities.do` | Input prices and quantities. |
| Table 3 | `do/analysis/main/Table3_EntOutcomes.do` | Enterprise outcomes. |
| Table 4 | `do/analysis/main/Table4_FigureB3_OutputPrices.do` | Also produces Figure B.3. |
| Table 5 | `do/analysis/multiplier/0_multiplier_master.do` and component scripts in `do/analysis/multiplier/` | Multiplier pipeline; also produces Appendix D tables. |

## Appendix A: study timeline and area

| Exhibit | Source program | Notes |
|---|---|---|
| Figure A.1a | None in the available executable tree | Identified by the upstream master as externally generated. |
| Figure A.1b | `do/analysis/main/FigureA1b_GE_timeline_expstart.do` | Timeline relative to experiment start. |
| Figure A.2 | None in the available executable tree | Identified as a manually generated GIS map; spatial source material is not included. |

## Appendix B: supporting figures and tables

| Exhibit | Source program | Notes |
|---|---|---|
| Figure B.1 | `do/analysis/main/FigureB1_LinearityChecks.do` | Nonlinear spillover estimates. |
| Figure B.2 | `do/analysis/main/FigureB2_Heterogeneity.do` | Heterogeneity in prespecified outcomes. |
| Figure B.3 | `do/analysis/main/Table4_FigureB3_OutputPrices.do` | Generated with Table 4. |
| Figure B.4 | `do/analysis/main/FigureB4_PriceEffects_ByProduct.R` | Requires product-level price intermediates. |
| Table B.1 | `do/analysis/main/TableB1_HHAssets.do` | Household assets. |
| Table B.2 | `do/analysis/main/TableB2_EntSector_Revenue.do` | Enterprise revenue by sector. |
| Table B.3 | `do/analysis/main/TableB3_EntOutcomes_Eligibility.do` | Enterprise outcomes by owner eligibility. |
| Table B.4 | `do/analysis/main/TableB4_AddLaborOutcomes.do` | Additional labor outcomes. |
| Table B.5 | `do/analysis/main/TableB5_AddLandOutcomes.do` | Additional land outcomes. |
| Table B.6 | `do/analysis/main/TableB6_ExternalityOutcomes.do` | Nonmarket outcomes and externalities. |
| Table B.7 | `do/analysis/main/TableB7_Inequality.do` | Inequality outcomes. |
| Table B.8 | `do/analysis/main/Table1_B8_F3_ExpSavingsIncome.do` | Extended version of Table 1. |
| Table B.9 | `do/analysis/main/TableB9_ExpSavingsIncome_NoMigrants.do` | Excludes respondents who migrated. |

## Appendix C: marginal propensity to consume

| Exhibit | Source program | Notes |
|---|---|---|
| Table C.1 | `do/analysis/main/TableC1_MPC.do` | Requires multiplier globals and intermediate files. |

## Appendix D: transfer multiplier

| Exhibit | Source program | Notes |
|---|---|---|
| Tables D.1–D.2 | `do/analysis/multiplier/ImportShares_globals_TablesD1_D2.do` | Import-share inputs and tables. |
| Tables D.3–D.6 | `do/analysis/multiplier/0_multiplier_master.do` and component multiplier scripts | Alternative assumptions, extended geography, and nominal/real multiplier variants. |

## Appendix E: study design and intervention

| Exhibit | Source program | Notes |
|---|---|---|
| Figure E.1 | None in the available executable tree | Identified as a GIS-produced spatial-variation figure; source material is not included. |

## Appendix F: household data

| Exhibit | Source program | Notes |
|---|---|---|
| Table F.1 | `do/analysis/main/TableF1_HH_Attrition.do` | Tracking and attrition. |
| Table F.2 | `do/analysis/main/TableF2_HH_Balance.do` | Household balance. |
| Table F.3 | `do/analysis/main/Table1_B8_F3_ExpSavingsIncome.do` | Coefficients generated with Table 1. |

## Appendix G: enterprise data

| Exhibit | Source program | Notes |
|---|---|---|
| Table G.1 | `do/analysis/main/TableG1_Ent_SectorStats.do` | Enterprise composition by sector. |
| Table G.2 | `do/analysis/main/TableG2_EntOutcomes_NoBL.do` | Enterprise outcomes without baseline controls. |
| Table G.3 | `do/analysis/main/TableG3_EntBalance.do` | Enterprise balance. |

## Appendix H: price data

| Exhibit | Source program | Notes |
|---|---|---|
| Table H.1 | None in the available executable tree | Identified as manually assembled. |
| Table H.2 | `do/analysis/main/TableH2_OutputPrices_DistRoad.do` | Road-distance market-access measure. |
| Figure H.1 | `do/analysis/main/FigureH1_H2_AdditionalPriceAnalyses.do` | Price index by treatment intensity. |
| Figure H.2 | `do/analysis/main/FigureH1_H2_AdditionalPriceAnalyses.do` | Cumulative price effects. |
| Table H.3 | `do/analysis/main/TableH3_OutputPrices_RadiiRobustness.do` | Alternative radii bands. |
| Table H.4 | `do/analysis/main/TableH4_OutputPrices_IV.do` | Instrumental-variables specification. |
| Table H.5 | `do/analysis/main/TableH5_EntPrices.do` | Local manufacturing and services prices. |

## Appendix I: alternative spatial approaches

| Exhibit | Source program |
|---|---|
| Table I.1 | `do/analysis/main/TableI1_RadiiRobustness_ExpSavingsIncome.do` |
| Table I.2 | `do/analysis/main/TableI2_RadiiRobustness_InputPricesQuantities.do` |
| Table I.3 | `do/analysis/main/TableI3_EntOutcomes_RadiiRobustness.do` |
| Table I.4 | `do/analysis/main/TableI4_BIC_splitsample_ExpSavingsIncome.do` |
| Table I.5 | `do/analysis/main/TableI5_BIC_splitsample_InputPricesQuantities.do` |
| Table I.6 | `do/analysis/main/TableI6_BIC_splitsample_Enterprise.do` |
| Table I.7 | `do/analysis/main/TableI7_MaxRadius_ExpSavingsIncome.do` |
| Table I.8 | `do/analysis/main/TableI8_MaxRadius_InputPricesQuantities.do` |
| Table I.9 | `do/analysis/main/TableI9_MaxRadius_EntOutcomes.do` |
| Table I.10 | `do/analysis/main/TableI10_RI_ExpSavingsIncome.do` |
| Table I.11 | `do/analysis/main/TableI11_RI_InputPricesQuantities.do` |
| Table I.12 | `do/analysis/main/TableI12_RI_Enterprise.do` |
| Table I.13 | `do/analysis/main/TableI13_RI_OutputPrices.do` |

Tables I.1–I.13 are particularly sensitive to the resampling profile, random seed, spatial inputs, and dependency versions. With `runGPS = 0`, applicable inference can differ from the published restricted-coordinate specification.

## Appendix J: pre-analysis plans

| Exhibit | Source program | Notes |
|---|---|---|
| Table J.1 | `do/analysis/main/TableJ1_PAP_primaryoutcomes.do` | Prespecified primary household-welfare outcomes. |

## In-text statistics

| Output group | Source program |
|---|---|
| Additional paper and appendix statistics | `do/analysis/sumstats/sumstats_intext.do` |
| Main-text S-W first-stage statistics | `do/analysis/sumstats/SW_code.do` |
| Multiplier S-W first-stage statistics | `do/analysis/sumstats/sw_firststage_mult.do` |

## Curated wrapper map

The scripts below provide section-oriented convenience runs. Their equation labels are repository workflow labels and should not be treated as a substitute for the exhibit mapping above.

| Wrapper | Coverage |
|---|---|
| `scripts/run_eq1_eq2_outputs.do` | Household expenditure/input tables and selected supporting exhibits. |
| `scripts/run_eq3_outputs.do` | Labor/input extension and related household outputs. |
| `scripts/run_eq4_eq6_price_outputs.do` | Main and appendix price analyses. |
| `scripts/run_eq7_multiplier_outputs.do` | Multiplier sequence and Appendix D outputs. |
| `scripts/run_tablec1_mpc_output.do` | Table C.1. |
| `scripts/run_eq8_eq9_enterprise_outputs.do` | Main and appendix enterprise analyses. |

For a comprehensive source-order inventory, use `ge_analysis.do` as the authoritative master mapping within this package.
