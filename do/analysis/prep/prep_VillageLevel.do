
/*** This do file generates temporary datasets of village-level quantities for use
     with enterprise analyses ***/

***************************************************
** 1. Prepare important village-level quantities **
***************************************************


** get total number of households by group and village **
use "$da/GE_HHLevel_ECMA.dta", clear
gen run_id = _n
keep village_code treat hi_sat eligible hhweight_EL
bys village_code: egen n_elig = sum(hhweight_EL) if eligible == 1
bys village_code: egen n_inelig = sum(hhweight_EL) if eligible == 0
bys village_code: egen n_hh = sum(hhweight_EL)
bys village_code: egen n_hh_treat = sum(hhweight_EL) if eligible == 1 & treat == 1
replace n_hh_treat = 0 if treat == 0
bys village_code: egen n_hh_untreat = sum(hhweight_EL) if eligible == 0 | treat == 0

sum hhweight_EL if treat == 1
local n_hh_treatall = `r(sum)'

sum hhweight_EL if treat == 0
local n_hh_controlall = `r(sum)'

sum hhweight_EL if treat == 0 & hi_sat == 0
local n_hh_lowsatcontrol = `r(sum)'

sum hhweight_EL if eligible == 1 & treat == 1
local n_hh_treat = `r(sum)'
sum hhweight_EL if eligible == 0 | treat == 0
local n_hh_untreat = `r(sum)'
sum hhweight_EL
local n_hh_tot = `r(sum)'

collapse (mean) n_elig n_inelig n_hh n_hh_treat n_hh_untreat, by(village_code)
tempfile temphh
save `temphh'

** get total number of enterprises by group and village, baseline **
use "$da/GE_VillageLevel_ECMA.dta", clear
gen run_id = _n
gen date = run_id // pseudo-panel of depth one.

cap la var n_allents_BL "Number of enterprises"
cap la var n_operates_from_hh_BL "Number of enterprises, non-ag operated from hh"
cap la var n_operates_outside_hh_BL "Number of enterprises, non-ag operated outside hh"
cap la var n_ent_ownfarm_BL "Number of enterprises, own-farm agriculture"
keep village_code n_allents_BL n_operates_from_hh_BL n_operates_outside_hh_BL n_ent_ownfarm_BL
tempfile tempent_bl
save `tempent_bl'



** get total number of enterprises by group and village, endline **
use "$da/GE_VillageLevel_ECMA.dta", clear
gen run_id = _n
gen date = run_id //  pseudo-panel of depth one.

cap la var n_allents "Number of enterprises"
cap la var n_operates_from_hh "Number of enterprises, non-ag operated from hh"
cap la var n_operates_outside_hh "Number of enterprises, non-ag operated outside hh"
cap la var n_ent_ownfarm "Number of enterprises, own-farm agriculture"
keep village_code n_allents n_operates_from_hh n_operates_outside_hh
tempfile tempent_el
save `tempent_el'
