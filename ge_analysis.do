/*** ge_analysis build pipeline
  This file implements the project command for the GE analysis pipeline.
  It serves as the master do file for analysis.
***/

*** Initialization ***
version 15.1
set more off
set varabbrev off
capture macro drop RUN_ROOT

project, doinfo
local pdir=r(pdir)
adopath ++ "`pdir'/ado"

* make directories if needed
cap mkdir "`pdir'/results"
cap mkdir "`pdir'/results/tables"
cap mkdir "`pdir'/results/tables/coeftables"
cap mkdir "`pdir'/results/figures"
cap mkdir "`pdir'/temp"
cap mkdir "`pdir'/logs"
cap mkdir "`pdir'/data"

*** Load dependencies into project ***
project, relies_on("`pdir'/do/set_environment.do")

local helper_files : dir "`pdir'/ado" files "*.ado"
foreach file of local helper_files {
	project, relies_on("`pdir'/ado/`file'")
}

*** running globals ***
project, original(do/GE_global_setup.do)
include do/GE_global_setup.do

*** running runGPS global. May need to have this later, before files that we won't want to do without GPS ***
project, original(do/global_runGPS.do)
include do/global_runGPS.do

project, original("`pdir'/data/pp_GDP_calculated.dta")
use "`pdir'/data/pp_GDP_calculated.dta", clear
global pp_GDP = pp_GDP[1]
global pp_GDP_r = pp_GDP_r[1]

*********************************************************


***********************************
*      Main Tables and Figure     *
***********************************

* Figure 1: Multiplier figure **
* generated using R. User must run multiplier_master.do before creating this figure.
* See below to run all R files.

* Table 1: Expenditure, Savings and Income  **
* Also creates Table B.8 and Table F.3  **
project, do(do/analysis/main/Table1_B8_F3_ExpSavingsIncome.do)

* Table 2: Input Prices and Quantities **
project, do(do/analysis/main/Table2_InputPricesQuantities.do)

* Table 3: Enterprise Outcomes **
project, do(do/analysis/main/Table3_EntOutcomes.do)

* Table 4: Output Prices **
* Also creates Figure B.3
project, do(do/analysis/main/Table4_FigureB3_OutputPrices.do)


** Table 5: Transfer Multiplier Estimates **
* Made with multiplier master file which creates the necessary multiplier data files and other related tables
* This multiplier master file creates the following tables:
* Table 5: Transfer Multiplier Estimates
* Table D1, D2: Durable and Non-Durable Import Shares
* Table D.3: Transfer Multiplier Estimates - Adjusting for Imported Intermediates
* Table D.4: Transfer Multiplier - Alternative Assumptions for the Initial Spending Impact
* Table D.5: Transfer Multipliers including Rarieda data, adjusting for imported intermediates
* Table D.6: Nominal Transfer Multiplier
project, do(do/analysis/multiplier/0_multiplier_master.do)


**********************************************
*                APPENDICES                  *
**********************************************

***********************************************
*  APPENDIX A: Study Timeline and Study Area  *
***********************************************

* Figure A.1 panel a: generated externally

* Figure A.1 panel b: Timeline relative to experiment start
project, do(do/analysis/main/FigureA1b_GE_timeline_expstart.do)

* Figure A.2: Study area
* This figure was created externally in ArcGIS; restricted geospatial inputs are not part of this release.

***********************************************
*  APPENDIX B: Supporting Figures and Tables  *
***********************************************

***** Figures ******
* Figure B.1: Non-linear Spillover Estimates
project, do(do/analysis/main/FigureB1_LinearityChecks.do)

* Figure B.2: Little heterogeneity in pre-specified primary outcomes
project, do(do/analysis/main/FigureB2_Heterogeneity.do)

* Figure B.3: Output price effects by market access
* created by the file that creates Table 4 above

* Figure B.4: Output price effects at the product level
* R file: do/analysis/main/FigureB4_PriceEffects_ByProduct.R


***** Tables *****
* Table B.1: Household Assets by Productivity Status
project, do(do/analysis/main/TableB1_HHAssets.do)

* Table B.2: Enterprise revenue effects by sector
project, do(do/analysis/main/TableB2_EntSector_Revenue.do)

* Table B.3: Enterprise outcomes by owner eligibility
project, do(do/analysis/main/TableB3_EntOutcomes_Eligibility.do)

* Table B.4: Input prices and quantities: additional labor outcomes **
project, do(do/analysis/main/TableB4_AddLaborOutcomes.do)

* Table B.5: Input prices and quantities: additional land outcomes **
project, do(do/analysis/main/TableB5_AddLandOutcomes.do)

* Table B.6 Non-market outcomes and Externalities **
project, do(do/analysis/main/TableB6_ExternalityOutcomes.do)

* Table B.7: Inequality *
project, do(do/analysis/main/TableB7_Inequality.do)

* Table B.8: Expenditure, Savings and Income: Extended version *
* see Table 1 above

* Table B.9: Expenditure, Savings and Income results, excluding respondents who migrated**
project, do(do/analysis/main/TableB9_ExpSavingsIncome_NoMigrants.do)



***********************************************
*       APPENDIX C: Estimating the MPC        *
***********************************************

* Table C.1: Estimates of recipients' marginal propensity to consume
* User needs to run the multiplier files sequence (see above under Table 5) before this do file
* for the neccesary globals and data files
project, do(do/analysis/main/TableC1_MPC.do)



***********************************************
*       APPENDIX D:  Transfer Multiplier      *
***********************************************
* Tables for Apppendix D are created by 0_multiplier_master.do as noted above under Table 5



************************************************************
*  APPENDIX E:  Details on Study Design and Intervention   *
************************************************************
* Figure E.1: Spatial Variation of Data and Treatment
* Made with ArcGIS



***********************************************
*    APPENDIX F:  Household Data Appendix     *
***********************************************
* Table F.1: Household survey tracking and attrition
project, do(do/analysis/main/TableF1_HH_Attrition.do)

* Table F.2: Household balance
project, do(do/analysis/main/TableF2_HH_Balance.do)

* Table F.3: Coefficient estimates for Expenditure, Savings and Income
* created by file for Table 1 above


***********************************************
*    APPENDIX G:  Enterprise Data Appendix    *
***********************************************

* Table G.1: Composition of enterprises by sector
project, do(do/analysis/main/TableG1_Ent_SectorStats.do)

* Table G.2: Enterprise outcomes without baseline controls
project, do(do/analysis/main/TableG2_EntOutcomes_NoBL.do)

* Table G.3: Enterprise balance
project, do(do/analysis/main/TableG3_EntBalance.do)



***********************************************
*       APPENDIX H:  Price Data Appendix      *
***********************************************

* Table H.1: List of market products by category
//Made manually

* Table H.2: Output Prices using distance to main road as market access measure
project, do(do/analysis/main/TableH2_OutputPrices_DistRoad.do)

* Figure H.1 Price index by treatment intensity *
****************
project, do(do/analysis/main/FigureH1_H2_AdditionalPriceAnalyses.do)

* Figure H.2 Cumulative price effects *
***************************************
* made by the above file *

* Table H.3: Robustness to fixing alternative radii bands: Output Prices
project, do(do/analysis/main/TableH3_OutputPrices_RadiiRobustness.do)

* Table H.4: Output Prices - IV Specification
project, do(do/analysis/main/TableH4_OutputPrices_IV.do)

* Table H.5: Local manufacturing and services prices
project, do(do/analysis/main/TableH5_EntPrices.do)


***********************************************************************
* APPENDIX I: Robustness to Alternative Spatial Modelling Approaches  *
***********************************************************************

* Table I.1: Robustness to fixing alternative radii bands: Expenditures, Savings and Income
project, do(do/analysis/main/TableI1_RadiiRobustness_ExpSavingsIncome.do)

* Table I.2: Robustness to fixing alternative radii bands: Input Prices and Quantities
project, do(do/analysis/main/TableI2_RadiiRobustness_InputPricesQuantities.do)

* Table I.3: Robustness to fixing alternative radii bands: Enterprise Outcomes
project, do(do/analysis/main/TableI3_EntOutcomes_RadiiRobustness.do)

* Table I.4: BIC split sample approach for household expenditure, savings and income outcomes
project, do(do/analysis/main/TableI4_BIC_splitsample_ExpSavingsIncome.do)

* Table I.5: BIC split sample approach for input prices and quantities
project, do(do/analysis/main/TableI5_BIC_splitsample_InputPricesQuantities.do)

* Table I.6: BIC split sample approach for enterprise outcomes
project, do(do/analysis/main/TableI6_BIC_splitsample_Enterprise.do)

* Table I.7: Maximum Radius Chosen by the BIC Algorithm (in km), expenditure, saving and income outcomes
project, do(do/analysis/main/TableI7_MaxRadius_ExpSavingsIncome.do)

* Table I.8: Maximum Radius Chosen by the BIC Algorithm (in km), input prices and quantities
project, do(do/analysis/main/TableI8_MaxRadius_InputPricesQuantities.do)

* Table I.9: Maximum Radius Chosen by the BIC Algorithm (in km), enterprise outcomes
project, do(do/analysis/main/TableI9_MaxRadius_EntOutcomes.do)

* Table I.10: Randomization inference for expenditure, savings and income outcomes
project, do(do/analysis/main/TableI10_RI_ExpSavingsIncome.do)

* Table I.11: Randomization inference for input prices and quantities
project, do(do/analysis/main/TableI11_RI_InputPricesQuantities.do)

* Table I.12: Randomization inference for enterprise outcomes
project, do(do/analysis/main/TableI12_RI_Enterprise.do)

* Table I.13: Randomization inference for price outcomes
project, do(do/analysis/main/TableI13_RI_OutputPrices.do)



***********************************************
*    APPENDIX J:  Study Pre-Analysis Plans    *
***********************************************

* Table J.1: Pre-specified primary outcomes, household welfare plan *
project, do(do/analysis/main/TableJ1_PAP_primaryoutcomes.do)



***********************************************
*   STATISTICS MENTIONED IN THE PAPER TEXT    *
***********************************************

** This .do file outputs additional statistics that are mentioned in the text of the paper or appendix but do not refer to a Table or Figure
project, do(do/analysis/sumstats/sumstats_intext.do)

** S-W First stage numbers - main text
project, do(do/analysis/sumstats/SW_code.do)

** S-W First stage numbers -- multiplier
project, do(do/analysis/sumstats/sw_firststage_mult.do)
