/*** Filename: global_runGPS.do -- setting global for whether or not analyses use spatial SEs. This file is then run when needed ***/

* Public replication package: restricted GPS files are not included.
global runGPS = 0

assert $runGPS == 1 | $runGPS == 0
