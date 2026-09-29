# Backward-compatible, headless entry point.
# Prefer: Rscript run_figures.R

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
repo_root <- Sys.getenv("REPO_ROOT", unset = "")
if (!nzchar(repo_root)) {
  wrapper <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else getwd()
  repo_root <- if (dir.exists(wrapper)) wrapper else dirname(wrapper)
}

repo_root <- normalizePath(repo_root, mustWork = TRUE)
Sys.setenv(REPO_ROOT = repo_root)
source(file.path(repo_root, "run_figures.R"), chdir = FALSE)
