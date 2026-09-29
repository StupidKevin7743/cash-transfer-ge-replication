*! version 1.0.1  27may2013
* Updated by MWW -- adding in touse to index construction
* This is an add-on to egen, written by Johannes Haushofer, May 27, 2013. The command is as follows:
* egen indexvariable = weightave(varlist) [, normby(var)]
* The output is a new variable (indexvariable) which contains a weighted average of
* varlist. The weighted average is computed following Anderson (2011) by subtracting the mean,
* normalizing by the standard deviation, computing the covariance matrix, inverting it, summing
* the rows of the covariance matrix, and then weighting each variable with its corresponding
* entry in the summed inverted covariance matrix. After that divide by the sum of the weights
* just to normalize.
* The "normby(var)" option, where var is a dummy variable, specifies that the standard deviation
* through which the mean-subtracted variables are divided is computed only from those observations
* where var = 1. For example, we often want to subtract the mean of the whole sample, but divie by
* the standard deviation of the control group only. This can be achieved by calling:
* egn indexvariable = weightave(varlist), normby(controldummy)
* A special case occurs when varlist has only one element. In this case this variable receives
* weight 1, and the ouput is simply a z-scored version of that variable.
* Note that step 1 in Anderon's procedure - inverting variables so that "positive" outcomes
* go with higher values for all variables - needs to be done by hand before calling egen weightave.
* Further note that the program does its own z-scoring (as explained above), so no need to standardize
* variables before calling it.

program define _gweightave, rclass
	gettoken type 0 : 0
	gettoken h    0 : 0
	gettoken eqs  0 : 0

	syntax varlist(min=1) [if] [in] [, BY(string)] [, normby(str)]
	if `"`by'"' != "" {
		_egennoby rowmean() `"`by'"'
		/* NOTREACHED */
	}

	* If no variable
	capture confirm numeric variable `normby'
	if _rc {
		tempvar normby
		gen `normby' = 1
	}

	quietly correlate `varlist'

	mat Sigma = r( C )
	* invert the covariance matrix and sum the rows; these are the weights.
	mata: Sigma = st_matrix("Sigma")
	mata: Sigma=editmissing(Sigma,0)
	mata: Sigmainv = invsym(Sigma)

	mata: w = rowsum(Sigmainv)
	mata: st_matrix("w",w)
	di "Weighting matrix:"
		mat l w
*		return matrix w = w

	* create an index by summing the z-scored variables, weighted by their respective weights
	tempvar index W x
	gen `index' = 0
	gen `W' = 0
	gen `h' = 0

	tempvar NOBS touse g
	mark `touse' `if' `in'

	*quietly {
		local mynum = 0
		foreach x of varlist `varlist'  {
			local ++mynum
			qui sum `x' if `normby' & `touse'
			local mysd = r(sd)
			qui sum `x' if `normby' & `touse'
			dis "mean: `r(mean)'. SD: `mysd'"
			local mymean = r(mean)
			tempvar vname
			gen `vname' = (`x' - `mymean')/`mysd' if `touse'
			replace `index' = `index' + w[`mynum',1] * `vname' if `vname' ~=.
			replace `W' = `W' + w[`mynum',1] if `vname' ~= .
		}

		replace `index' = 1/`W' * `index'
		tempvar temp
		egen `temp' = rownonmiss(`varlist')
		replace `index' = . if `temp'==0
		qui sum `index' if `normby'
			dis "mean: `r(mean)'. SD: `mysd'"
		if "`r(mean)'" ~="" & "`r(sd)'" ~= "0" & "`r(sd)'" ~= "" {
			replace `index' = (`index' - `r(mean)') / `r(sd)'
			}
*		else {
*			replace `index' = (`index' - `r(mean)')
*			}

		*gen `type' `h' = `index' if `touse'
		replace `h' = `index' if `touse'
	*} // quietly
end
