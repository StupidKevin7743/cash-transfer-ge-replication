version 15.1
set more off
pause off


** Stata options
set more off
set matsize 1000
set maxvar 32000


if "${REPO_ROOT}" == "" {
    if "${ge_dir}" != "" global REPO_ROOT "${ge_dir}"
    else global REPO_ROOT "`c(pwd)'"
}

global ge_dir "${REPO_ROOT}"
global dir "${REPO_ROOT}"

adopath ++ "$dir/ado"


* Provide a compatibility shim only when the real project command is absent.
capture which project
if _rc {
    program define project, rclass
        version 15.1
        syntax [, DOINFO DO(string asis) CREATES(string asis) USES(string asis) ORIGINAL(string asis) RELIES_ON(string asis) PRESERVE ]

        if "`doinfo'" != "" {
            return local pdir "$REPO_ROOT"
            return local pname "cash_transfer_replication"
            exit
        }

        if `"`do'"' != "" do `"`do'"'
    end
}
