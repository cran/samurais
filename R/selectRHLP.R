#' selecRHLP implements a model selection procedure to select an optimal RHLP
#' model with unknown structure.
#'
#' @details selectRHLP selects the optimal MRHLP model among a set of model
#'   candidates by optimizing a model selection criteria, including the Bayesian
#'   Information Criterion (BIC). This function first fits the different RHLP
#'   model candidates by varying the number of regimes `K` from `Kmin` to `Kmax`
#'   and the order of the polynomial regression `p` from `pmin` to `pmax`. The
#'   model having the highest value of the chosen selection criterion is then
#'   selected.
#'
#' @param X Numeric vector of length \emph{m} representing the covariates/inputs
#'   \eqn{x_{1},\dots,x_{m}}.
#' @param Y Numeric vector of length \emph{m} representing the observed
#'   response/output \eqn{y_{1},\dots,y_{m}}.
#' @param Kmin The minimum number of regimes (RHLP components).
#' @param Kmax The maximum number of regimes (RHLP components).
#' @param pmin The minimum order of the polynomial regression.
#' @param pmax The maximum order of the polynomial regression.
#' @param criterion The criterion used to select the RHLP model ("BIC", "AIC").
#' @param verbose Optional. A logical value indicating whether or not a summary
#'   of the selected model should be displayed.
#' @return selectRHLP returns an object of class [ModelRHLP][ModelRHLP]
#'   representing the selected RHLP model according to the chosen `criterion`.
#' @seealso [ModelRHLP]
#' @export
#'
#' @examples
#' data(univtoydataset)
#'
#' # Let's select a RHLP model on a time series with 3 regimes:
#' data <- univtoydataset[1:320,]
#'
#' selectedrhlp <- selectRHLP(X = data$x, Y = data$y,
#'                            Kmin = 2, Kmax = 4, pmin = 0, pmax = 1)
#'
#' selectedrhlp$summary()
selectRHLP <- function(X, Y, Kmin = 1, Kmax = 10, pmin = 0, pmax = 4, criterion = c("BIC", "AIC"), verbose = TRUE) {

  criterion <- match.arg(criterion)

  vrhlp <- Vectorize(function(K, p, X1 = X, Y1 = Y) emRHLP(X = X1, Y = Y1, K, p),
                     vectorize.args = c("K", "p"))

  rhlp <- outer(Kmin:Kmax, pmin:pmax, vrhlp)

  if (criterion == "BIC") {
    results <- apply(rhlp, 1:2, function(x) x[[1]]$stat$BIC)
  } else {
    results <- apply(rhlp, 1:2, function(x) x[[1]]$stat$AIC)
  }
  rownames(results) <- sapply(Kmin:Kmax, function(x) paste0("(K = ", x, ")"))
  colnames(results) <- sapply(pmin:pmax, function(x) paste0("(p = ", x, ")"))


  selected <- rhlp[which(results == max(results), arr.ind = T)][[1]]

  if (verbose) {
    cat(paste0("The RHLP model selected via the \"", criterion, "\" has K = ",
               selected$param$K, " regimes \n and the order of the ",
               "polynomial regression is p = ", selected$param$p, "."))
    cat("\n")
    cat(paste0("BIC = ", selected$stat$BIC, "\n"))
    cat(paste0("AIC = ", selected$stat$AIC, "\n"))
  }

  return(selected)

}
