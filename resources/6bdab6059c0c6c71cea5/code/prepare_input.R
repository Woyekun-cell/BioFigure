args <- commandArgs(TRUE)
stopifnot(length(args) == 2L)
x <- readxl::read_excel(args[1], "snRNA-seq proportions", .name_repair="minimal")
stopifnot(identical(dim(x),c(437L,92L)),identical(names(x)[1],"individualID"),
          !anyNA(x),!anyDuplicated(x$individualID),!anyDuplicated(names(x)),
          all(vapply(x[-1],is.numeric,logical(1))))
readr::write_csv(x,args[2])
round_trip <- readr::read_csv(args[2],show_col_types=FALSE)
stopifnot(identical(names(x),names(round_trip)),identical(x$individualID,round_trip$individualID),
          max(abs(as.matrix(x[-1])-as.matrix(round_trip[-1]))) < 1e-15)
