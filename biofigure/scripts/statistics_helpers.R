# Limited analysis helpers. Method choice/diagnostics remain task-specific.
# No automatic deletion, aggregation, normality-based switching, or plotting.
bf_statistics_data <- function(data, response, factors, unit, independent=TRUE) {
  required <- c(response, factors, unit)
  if (!is.data.frame(data) || !all(required %in% names(data))) stop('required statistical columns missing')
  if (anyNA(data[required])) stop('missing values require an explicit preprocessing decision')
  if (!is.numeric(data[[response]]) || any(!is.finite(data[[response]]))) stop('response must contain finite numeric values')
  if (any(!nzchar(as.character(data[[unit]])))) stop('empty experimental-unit ID')
  if (independent && anyDuplicated(data[[unit]])) stop('repeated unit IDs cannot be treated as independent observations')
  for (field in factors) {
    if (any(!nzchar(as.character(data[[field]])))) stop('empty factor level')
    data[[field]] <- droplevels(factor(data[[field]]))
  }
  data
}

bf_contrast_row <- function(test, lhs, rhs, n_lhs, n_rhs, estimate, method) {
  if (any(!is.finite(c(test$p.value,test$conf.int,estimate,test$statistic,test$parameter)))) stop('nonfinite statistical result; do not label as nonsignificant')
  data.frame(comparison_id=paste(lhs,rhs,sep='_minus_'), lhs=lhs, rhs=rhs,
    direction='lhs_minus_rhs', n_lhs=n_lhs, n_rhs=n_rhs, method=method,
    estimand='mean_difference', estimate=unname(estimate),
    ci_low=unname(test$conf.int[1]), ci_high=unname(test$conf.int[2]),
    ci_scope='pointwise_95_percent', statistic=unname(test$statistic),
    df=unname(test$parameter), p_raw=test$p.value, status='computed',
    stringsAsFactors=FALSE)
}

bf_welch_contrast <- function(data, response, group, unit, lhs, rhs) {
  d <- bf_statistics_data(data,response,group,unit)
  if (lhs == rhs || !setequal(levels(d[[group]]),c(lhs,rhs))) stop('explicit two-group contrast must match observed groups')
  x <- d[[response]][d[[group]]==lhs]; y <- d[[response]][d[[group]]==rhs]
  if (min(length(x),length(y))<2) stop('insufficient values for two-sample variance estimates')
  test <- stats::t.test(x,y,paired=FALSE,var.equal=FALSE,alternative='two.sided',conf.level=0.95)
  bf_contrast_row(test,lhs,rhs,length(x),length(y),mean(x)-mean(y),'Welch t')
}

bf_paired_contrast <- function(data, response, condition, unit, lhs, rhs) {
  d <- bf_statistics_data(data,response,condition,unit,independent=FALSE)
  if (lhs == rhs || !setequal(levels(d[[condition]]),c(lhs,rhs))) stop('explicit two-condition contrast must match observed conditions')
  if (anyDuplicated(d[c(unit,condition)])) stop('duplicate unit-condition keys; resolve technical repeats before pairing')
  a <- d[d[[condition]]==lhs,c(unit,response)]; b <- d[d[[condition]]==rhs,c(unit,response)]
  if (!setequal(a[[unit]],b[[unit]])) stop('incomplete pairs require an explicit missing-pair decision')
  order_b <- match(a[[unit]],b[[unit]])
  x <- a[[response]]; y <- b[[response]][order_b]
  if (length(x)<2) stop('insufficient complete pairs')
  test <- stats::t.test(x,y,paired=TRUE,alternative='two.sided',conf.level=0.95)
  bf_contrast_row(test,lhs,rhs,length(x),length(y),mean(x-y),'Paired t')
}

bf_oneway_test <- function(data, response, group, unit, method) {
  d <- bf_statistics_data(data,response,group,unit)
  if (nlevels(d[[group]])<2 || any(table(d[[group]])<2)) stop('one-way analysis needs replicated observed groups')
  test <- switch(method,
    welch=stats::oneway.test(d[[response]] ~ d[[group]],var.equal=FALSE),
    equal_variance=stats::oneway.test(d[[response]] ~ d[[group]],var.equal=TRUE),
    stop('declare method: welch or equal_variance; diagnostics are not automated'))
  if (any(!is.finite(c(test$p.value,test$statistic,test$parameter)))) stop('degenerate one-way analysis; resolve variance and design')
  data.frame(method=test$method,statistic=unname(test$statistic),
    df_numerator=unname(test$parameter[1]),df_denominator=unname(test$parameter[2]),
    p_raw=test$p.value,n_units=nrow(d),status='computed',stringsAsFactors=FALSE)
}

bf_two_factor_model <- function(data, response, factors, unit, covariates=character()) {
  if (length(factors)!=2 || anyDuplicated(factors)) stop('this helper supports exactly two distinct design factors')
  columns <- c(response,factors,unit,covariates)
  if (any(make.names(columns)!=columns) || anyDuplicated(columns)) stop('use distinct syntactic column names for this limited formula helper')
  if (!all(columns %in% names(data))) stop('model columns missing')
  d <- bf_statistics_data(data,response,factors,unit)
  if (anyNA(d[covariates]) || (length(covariates) && any(!vapply(d[covariates],is.numeric,logical(1))))) stop('covariates must be complete numeric values')
  if (length(covariates) && any(!is.finite(as.matrix(d[covariates])))) stop('nonfinite covariate')
  if (any(vapply(d[factors],nlevels,integer(1))<2)) stop('each factor needs at least two observed levels')
  if (any(table(d[factors])==0)) stop('empty factorial cells; estimability requires a task-specific model')
  formula <- stats::as.formula(paste(response,'~',paste(c(paste(factors,collapse=' * '),covariates),collapse=' + ')))
  fit <- stats::lm(formula,data=d,na.action=stats::na.fail)
  if (fit$rank<ncol(stats::model.matrix(fit)) || stats::df.residual(fit)<=0) stop('rank-deficient model or no residual degrees of freedom')
  fit  # No automatic marginal-main-effect P values or significance labels.
}

bf_two_factor_interaction <- function(fit, factors) {
  if (!inherits(fit,'lm') || length(factors)!=2) stop('provide the fitted two-factor linear model and factor names')
  term <- paste(factors,collapse=':')
  if (!term %in% attr(stats::terms(fit),'term.labels')) stop('interaction term missing')
  reduced_formula <- stats::update(stats::formula(fit),stats::as.formula(paste('. ~ . -',term)))
  reduced <- stats::lm(reduced_formula,data=stats::model.frame(fit),contrasts=fit$contrasts,na.action=stats::na.fail)
  comparison <- stats::anova(reduced,fit)
  if (any(!is.finite(c(comparison$F[2],comparison$`Pr(>F)`[2])))) stop('invalid interaction inference; inspect model diagnostics')
  data.frame(term=term,statistic=comparison$F[2],df_numerator=comparison$Df[2],
             df_denominator=stats::df.residual(fit),p_raw=comparison$`Pr(>F)`[2],
             method='nested-model interaction F test',status='computed',stringsAsFactors=FALSE)
}

bf_adjust_contrasts <- function(table, method, family_id) {
  if (!is.data.frame(table) || !'p_raw' %in% names(table) || !nrow(table)) stop('provide the complete raw-P comparison family')
  if ('p_adj' %in% names(table)) stop('p_adj already present; do not silently adjust twice')
  if (!method %in% c('holm','BH','BY','bonferroni','none') || length(family_id)!=1 || !nzchar(family_id)) stop('declare adjustment and family ID')
  if (anyNA(table$p_raw) || any(!is.finite(table$p_raw)) || any(table$p_raw<0 | table$p_raw>1)) stop('failed or invalid P values are not ns')
  if (method=='none' && nrow(table)>1) stop('this helper requires correction for a multi-contrast family; exceptions need task-specific code')
  table$p_adj <- stats::p.adjust(table$p_raw,method=method)
  table$adjustment <- method; table$family_id <- family_id
  table # Pointwise confidence intervals are not upgraded to simultaneous coverage.
}
