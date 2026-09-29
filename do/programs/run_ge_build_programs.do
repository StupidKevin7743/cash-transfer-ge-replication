/*
 * Filename: run_ge_build_programs.do
 * Description: This do file loads a few basic programs that are used by the code for
 *   GE programs. If there are additional programs that run across multiple do files, they
 *   can be added here in order to ensure compatibility across programs. Ensure that the date
 *   last modified is
 *
 * Programs defined by this do file:
    1. wins_top1
	2. trim_top2
 *
 * Author: Michael Walker
 * Last modified: 22 Feb 2018
 *
 */

** defining programs to winsorize and trim top 1% of monetary values, by eligibility status
cap program drop wins_top1 trim_top1
program define wins_top1
    syntax varlist(min=1) [, BY(varname numeric)]

    if ~mi("`by'") {
        *assert `by' == 0 | `by' == 1 if ~mi(`by')
        assert mod(`by',1) == 0 if ~mi(`by')
    }
    else {
        local by "eligible"
    }

    di "By: `by'"

    foreach var of varlist `varlist' {
        gen `var'_wins = `var' // setting equal to original variable for all values

        * replacing for by variable value
		levelsof `by', local(vals)
        foreach i in `vals' {
            qui: summ `var' if `by' == `i', d
            qui: replace `var'_wins = r(p99) if `var'_wins > r(p99) & `by' == `i' & ~mi(`var') // replacing non-missing values with by == 0 over 99th percentile
        }
		
        * labeling variable
        local vl : var label `var'
        if "`vl'" == "" {
            local vl "`var'"
        }
        la var `var'_wins "`vl' (wins)"
    }
end

program define trim_top1
    syntax varlist(min=1) [, BY(varname numeric)]

    if ~mi("`by'") {
        assert `by' == 0 | `by' == 1 if ~mi(`by')
    }
    else {
        local by "eligible"
    }

    di "By: `by'"


    foreach var of varlist `varlist' {

        gen `var'_trim = `var'

        forval i= 0 / 1 {
            qui: summ `var' if `by' == `i', d
            qui: replace `var'_trim = . if `var'_trim > r(p99) & `by' == `i'
        }


        local vl : var label `var'
        if "`vl'" == "" {
            local vl "`var'"
        }
        la var `var'_trim "`vl' (trim)"
    }
end

cap program drop me_prep
program define me_prep
    syntax varlist //, Generate(name)
    //confirm new variable `generate'
    foreach var of varlist `varlist' {
        qui: summ `var' if eligible == 1 & treat == 0 & hi_sat == 0, d // finding mean and sd for control villages in low saturation sublocations
        gen `var'_z = (`var' - `r(mean)') / `r(sd)'
        local vl : var label `var'
        la var `var'_z "`vl' (std)"
    }
end


cap program drop wins_topbottom1 trim_topbottom1
program define wins_topbottom1
    syntax varlist(min=1) [, BY(varname numeric)]

    if ~mi("`by'") {
        assert `by' == 0 | `by' == 1 if ~mi(`by')
    }
    else {
        local by "eligible"
    }

    di "By: `by'"

    foreach var of varlist `varlist' {

        gen `var'_wins2 = `var'
        forval i = 0 / 1 {
            qui: summ `var' if `by' == `i', d
            qui: replace `var'_wins2 = r(p99) if `var'_wins2 > r(p99) & `by' == `i' & ~mi(`var')
            qui: replace `var'_wins2 = r(p1) if `var'_wins2 < r(p1) & `by' == `i' & ~mi(`var')
        }

        local vl : var label `var'
        if "`vl'" == "" {
            local vl "`var'"
        }
        la var `var'_wins2 "`vl' (wins top and bottom)"
    }
end

program define trim_topbottom1
    syntax varlist(min=1) [, BY(varname numeric)]

    if ~mi("`by'") {
        assert `by' == 0 | `by' == 1 if ~mi(`by')
    }
    else {
        local by "eligible"
    }

    di "By: `by'"

    foreach var of varlist `varlist' {

        gen `var'_trim2 = `var'
        forval i = 0 / 1 {
            qui: summ `var' if `by' == `i', d
            qui: replace `var'_trim2 = . if `var'_trim2 > r(p99) & `by' == `i'
            qui: replace `var'_trim2 = . if `var'_trim2 < r(p1) & `by' == `i'

        }


        local vl : var label `var'
        if "`vl'" == "" {
            local vl "`var'"
        }
        la var `var'_trim2 "`vl' (trim top and bottom)"
    }
end

cap program drop replace_var
program define replace_var
    syntax, Keep(name) Drop(name)
    local k_type : type `keep'
    local d_type: type `drop'
    if strpos("`k_type'", "str") > 0 {
        replace `keep' = "" if `keep' == "."
    }
    if strpos("`d_type'", "str") > 0 {
        replace `drop' = "" if `drop' == "."
    }

    assert (mi(`keep') & ~mi(`drop')) | (~mi(`keep') & mi(`drop')) | (mi(`keep') & mi(`drop')) | (`keep' == `drop')

    replace `keep' = `drop' if mi(`keep') & ~mi(`drop')
    drop `drop'
end

* Generating different versions of index variables - one for eligible households (normalized by control, low sat among eligibles), one for ineligible households (normalized by control, low sat for ineligibles), and one overall, normalized by eligible, control, low sat
cap program drop gen_index_vers
program define gen_index_vers
    syntax varlist, PREfix(name) [Label(str)]
    * variables go in varlist, lead-in for name as prefix

    * eligible index
    egen `prefix'_e = weightave(`varlist') if eligible == 1, normby(control_lowsat)
    replace `prefix'_e = . if eligible != 1

    * ineligible index
    egen `prefix'_ie = weightave(`varlist') if eligible == 0, normby(control_lowsat)
    replace `prefix'_ie = . if eligible != 0

    * overall
    gen `prefix' = `prefix'_e if eligible == 1
    replace `prefix' = `prefix'_ie if eligible == 0

    if "`label'" != "" {
        la var `prefix'_e "`label', eligible HHs (norm by control, low sat)"
        la var `prefix'_ie "`label'. ineligible HHs (norm by control, low sat)"
        la var `prefix' "`label', all HHs (norm by eligibility status)"
    }

end
