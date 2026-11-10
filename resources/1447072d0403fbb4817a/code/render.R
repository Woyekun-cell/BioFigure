#!/usr/bin/env Rscript
args <- commandArgs(TRUE);stopifnot(length(args)==2)
script <- normalizePath(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE)))
root <- dirname(dirname(script));source(file.path(dirname(root),'scripts/render_simulation_common.R'))
render_case(root,normalizePath(args[1]),args[2],script)
