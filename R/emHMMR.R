#' emHMMR implemens the EM (Baum-Welch) algorithm to fit a HMMR model.
#'
#' emHMMR implements the maximum-likelihood parameter estimation of the HMMR
#' model by the Expectation-Maximization (EM) algorithm, known as Baum-Welch
#' algorithm in the context of HMMs.
#'
#'
#' @details emHMMR function implements the EM algorithm for the HMMR model. This
#'   function starts with an initialization of the parameters done by the method
#'   `initParam` of the class [ParamHMMR][ParamHMMR], then it alternates between
#'   the E-Step (method of the class [StatHMMR][StatHMMR]) and the M-Step
#'   (method of the class [ParamHMMR][ParamHMMR]) until convergence (until the
#'   relative variation of log-likelihood between two steps of the EM algorithm
#'   is less than the `threshold` parameter).
#'
#' @param X Numeric vector of length \emph{m} representing the covariates/inputs
#'   \eqn{x_{1},\dots,x_{m}}.
#' @param Y Numeric vector of length \emph{m} representing the observed
#'   response/output \eqn{y_{1},\dots,y_{m}}.
#' @param K The number of regimes/segments (HMMR components).
#' @param p Optional. The order of the polynomial regression. By default, `p` is
#'   set at 3.
#' @param variance_type Optional character indicating if the model is
#'   "homoskedastic" or "heteroskedastic" (i.e same variance or different
#'   variances for each of the K regmies). By default the model is
#'   "heteroskedastic".
#'
#' @param n_tries Optional. Number of runs of the EM algorithm. The solution
#'   providing the highest log-likelihood will be returned.
#'
#'   If `n_tries` > 1, then for the first run, parameters are initialized by
#'   uniformly segmenting the data into K segments, and for the next runs,
#'   parameters are initialized by randomly segmenting the data into K
#'   contiguous segments.
#' @param max_iter Optional. The maximum number of iterations for the EM
#'   algorithm.
#' @param threshold Optional. A numeric value specifying the threshold for the
#'   relative difference of log-likelihood between two steps of the EM as
#'   stopping criteria.
#' @param verbose Optional. A logical value indicating whether or not values of
#'   the log-likelihood should be printed during EM iterations.
#' @return EM returns an object of class [ModelHMMR][ModelHMMR].
#' @seealso [ModelHMMR], [ParamHMMR], [StatHMMR]
#' @export
#'
#' @examples
#' data(univtoydataset)
#' hmmr <- emHMMR(univtoydataset$x, univtoydataset$y, K = 5, p = 1, verbose = TRUE)
#'
#' hmmr$summary()
#'
#' hmmr$plot()
#'
emHMMR <- function(X, Y, K, p = 3, variance_type = c("heteroskedastic", "homoskedastic"), n_tries = 1, max_iter = 1500, threshold = 1e-6, verbose = FALSE) {

  nb_good_try <- 0
  total_nb_try <- 0
  best_loglik <- -Inf

  while (nb_good_try < n_tries) {

    if (n_tries > 1 && verbose) {
      cat(paste0("EM try number: ", nb_good_try + 1, "\n\n"))
    }
    total_nb_try <- total_nb_try + 1

    ## EM Initializaiton step
    ## Initialization of the Markov chain parameters, the regression coefficients, and the variance(s)
    variance_type <- match.arg(variance_type)
    param <- ParamHMMR$new(X = X, Y = Y, K = K, p = p, variance_type = variance_type)
    param$initParam(nb_good_try + 1)

    iter <- 0
    prev_loglik <- -Inf
    converged <- FALSE
    top <- 0

    stat <- StatHMMR(paramHMMR = param)

    while ((iter <= max_iter) && !converged) {

      # E step : calculate the tau_tk (p(Zt=k|y1...ym;theta)) and xi t_kl (and the log-likelihood) by
      #  forwards backwards (computes the alpha_tk and beta_tk)
      stat$EStep(param)

      # M step
      param$MStep(stat)

      # End of an EM iteration

      iter <-  iter + 1

      # Test of convergence
      lambda <- 1e-9 # If a bayesian prior on the beta's
      stat$loglik <- stat$loglik + log(lambda)

      if (verbose) {
        cat(paste0("EM: Iteration : ", iter, " || log-likelihood : "  , stat$loglik, "\n"))
      }

      if ((prev_loglik - stat$loglik) > 1e-4) {
        top <- top + 1
        if (top == 10) {
          warning(paste0("EM log-likelihood is decreasing from ", prev_loglik, "to ", stat$loglik, " !"))
        }
      }

      converged <- (abs(stat$loglik - prev_loglik) / abs(prev_loglik) < threshold)
      if (is.na(converged)) {
        converged <- FALSE
      } # Basically for the first iteration when prev_loglik is Inf

      prev_loglik <- stat$loglik
      stat$stored_loglik <- c(stat$stored_loglik, stat$loglik)

    } # End of the EM loop

    if (n_tries > 1 && verbose) {
      cat(paste0("Max value of the log-likelihood: ", stat$loglik, "\n\n"))
    }

    if (length(param$beta) != 0) {
      nb_good_try <- nb_good_try + 1
      total_nb_try <- 0

      if (stat$loglik > best_loglik) {

        statSolution <- stat$copy()
        paramSolution <- param$copy()

        best_loglik <- stat$loglik
      }
    }

    if (total_nb_try > 500) {
      stop(paste("can't obtain the requested number of classes"))
    }

  }

  if (n_tries > 1) {
    cat(paste0("Best value of the log-likelihood: ", statSolution$loglik, "\n"))
  }

  # Smoothing state sequences : argmax(smoothing probs), and corresponding binary allocations partition
  statSolution$MAP()

  # Finish the computation of statistics
  statSolution$computeStats(paramSolution)

  return(ModelHMMR(param = paramSolution, stat = statSolution))
}
