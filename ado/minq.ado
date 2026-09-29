** Desc: Wrapper for multproc to calculate minimum q-values from two-stage FDR correction
** Author: Justin Abraham
** Input: vector of p-values
** Output: vector of minimum q-values
** Options: q() is the name of the output vector, step() is size of the decrement, label() attaches names to the output vector

capture program drop minq
program define minq, eclass
syntax anything(name = p), [q(string)] [step(real 0)] [label(string)] [plabel]

if "`step'" == "" loc step = 0.001
if "`q'" == "" loc q = "Q"

preserve

clear

svmat `p'
ren `p'1 `p'

loc j = 1

forval i = 1(-`step')`step' {

	//di as text "Correction with q = `i'"

	qui multproc, pvalue(`p') method(krieger) puncor(`i') reject(reject`j')
	qui count if reject`j' == 0
	loc ++j

	if (`r(N)' == _N) {
		di "Cannot reject all hypotheses at step `step'"
		continue, break
	}

}

egen `q' = rowtotal(reject*)
replace `q' = 1 - (`q' * `step')
replace `q' = . if mi(`p')

if "`label'" == "" mkmat `q', mat(`q')

else {

	loc k = 1
	gen varn = ""

	foreach name in `label' {

		replace varn = "`name'" if _n == `k'
		loc ++k

	}

	mkmat `q', mat(`q') rownames(varn)

	if "`plabel'" != "" mkmat `p', mat(`p') rownames(varn)

}

restore

end
