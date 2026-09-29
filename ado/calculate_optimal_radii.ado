************************************************************
** Defining program to calculate optimal radii band **
************************************************************
* Author: Michael Walker
* Description: this program runs a series of IV regressions to
* determine the optimal radii for spatial spillover effects as
* outlined in GE pre-analysis plans.
* It returns scalars with the maximum and minimum of the radii band.
* Note: we may want to transition this to an ado file.

program define calculate_optimal_radii, rclass
  syntax varname [if] [aweight pweight fweight] , [blvars(string) elig hhnonrec ent vill quietly]

  * Elig: runs version for eligible households only
  * Nonrec: runs version for non-recipient households`
  * Ent: runs version for enterprises
  * One of these must be specified in order to develop endogenous and exogenous list of variables

if "`quietly'" != "" {
  di "Elig: `elig'"
  di "Nonrec: `hhnonrec'"
  di "Ent: `ent'"
  di "Vill: `vill'"
}

  if "`elig'" == "" & "`hhnonrec'" == "" & "`ent'" == "" & "`vill'" == "" {
    di "elig, hhnonrec, ent or vill must be specified"
    stop
  }
  * add in check to make sure more than one not selected


if "`hhnonrec'" != "" {
  loc eligible "eligible"
}
else {
  loc eligible ""
}

mata: optr = .,.,.,.,.,.,.,.,.,.

/* Listing endogenous and exogenous variables.
The following are present in all specifications. We then increment these by radii band */
if "`elig'" != "" | "`vill'" != "" {
  local endog_list "pp_actamt_ownvill"
  local exog_list "treat"
}
else if "`ent'" != "" {
    local endog_list "c.pp_actamt_ownvill#ent_type "
    local exog_list "treat#ent_type "
}
else {
    local endog_list ""
    local exog_list ""
}



forval r = 2(2)20 {
  local r2 = `r' - 2

  if "`elig'" != "" | "`vill'" != "" {
    local endog_list "`endog_list' pp_actamt_ov_`r2'to`r'km"
    local exog_list "`exog_list' share_ge_elig_treat_ov_`r2'to`r'km"
  }
  if "`hhnonrec'" != "" {
    local endog_list = "`endog_list'" + " c.pp_actamt_`r2'to`r'km#eligible"
    local exog_list = "`exog_list'" + " c.share_ge_elig_treat_`r2'to`r'km#eligible"
  }
  if "`ent'" != "" {
    local endog_list = "`endog_list'" + " c.pp_actamt_ov_`r2'to`r'km#ent_type"
    local exog_list = "`exog_list'" + " c.share_ge_elig_treat_ov_`r2'to`r'km#ent_type"
  }


if "`quietly'" != "" {
    di "Endogenous list: `endog_list'"
  di "Exogenous list: `exog_list'"
  di "Weights: `weight' `exp'"
  di "Baseline variables: `blvars'"
}

  if "`ent'" != ""{
    qui: ivreg2 `varlist' `blvars' ( `endog_list' =  `exog_list') i.ent_type [`weight' `exp'] `if'
    qui: estat ic
    mata: optr[`r'/2] = st_matrix("r(S)")[6]
  }
  else{
    qui: ivreg2 `varlist' `eligible' `blvars' ( `endog_list' =  `exog_list') [`weight' `exp'] `if'
    qui: estat ic
    mata: optr[`r'/2] = st_matrix("r(S)")[6]
  }
}

//matrix list optr

mata: st_numscalar("optr", select((1::10)', (optr :== min(optr)))*2)
* come back to try to add in full matrix of BICs -- would be nice to store
//return add


return scalar r_max = optr
return scalar r_min = optr - 2


end
