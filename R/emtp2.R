

#' Performs Gaussian likelihood optimization under Laplacian matrix constraints.
#'
#' This function implements a block descent algorithm to find the maximum of the 
#' Gaussian log-likelihood under the constraint that the concentration matrix is a Laplacian matrix.
#' @param G conditionally negative semidefinite matrix. This will be typically the empirical variogram matrix.
#' @param tol The convergence tolerance (default tol=1e-7). The algorithm terminates when the sum of absolute differences between two iterations is below `tol`.
#' @param initial_point if TRUE (default), the algorithm will construct an initial point before the iteration steps.
#' @param verbose if TRUE (default) the output will be printed.
#' @return `G_emtp2` the optimal value of the variogram matrix
#' @return `it` the number of iterations
#' @keywords block descent, concentration matrix, Laplacian matrix.
#' @export
emtp2 <- function(G,tol=1e-6, verbose = TRUE, initial_point = TRUE){
  d <- nrow(G)
  if (verbose==TRUE){
    cat("** The function maximizes the log-likelihood function under Laplacian matrix constraints.\n")
  }
  Gam <- G
  if (initial_point==TRUE){
    P <- diag(d)-matrix(1,d,d)/(d)
    S <- P%*%(-G/2)%*%P
    Z <- Zmatrix(S)
    Gam <- Sigma2Gamma(Z)
  }
  it <- 0
  if (verbose==TRUE){
    cat("The algorithm terminates when the sum of absolute differences between two iterations is below: ",tol,"\b.\n\n")
    cat("Iteration | Gap\n")
  }

  settings <- osqp::osqpSettings(verbose = FALSE, eps_abs = 1e-10, eps_rel = 1e-10)

  gap <- Inf
  while (gap>tol){
    Gam0 <- Gam
    for (i in 1:d) {
      A <- solve((-Gam/2)[-i,-i])
      Dmat <- 2*(A%*%matrix(1,d-1,d-1)%*%A-sum(A)*A)
      dvec <- -2*A%*%rep(1,d-1)
      bvec <- (-G/2)[-i,i]
      y <- osqp::solve_osqp(P = Dmat, q = dvec, A = diag(d-1), l = bvec, u = rep(0,d-1), settings)
      Gam[-i,i] <- Gam[i,-i] <- -2*y$x
    }
    it <- it+1
    gap <- sum(abs(Gam-Gam0))
    if (verbose==TRUE){
      cat(it,"\t  | ",gap,"\n")
    }
  }
  return(list(G_emtp2=Gam,it=it))
}




#' Computes the Z-matrix
#'
#' Copied from the R package "golazo" with kind permission by Piotr Zwiernik <piotr.zwiernik@utoronto.ca>.
#' This function outputs the Z matrix, that is, the unique ultrametric matrix dominating S. This matrix is used to connstruct a starting point in the GOLAZO algorithm when L=0 but U has strictly positive (off-diagonal entries).
#' @param S a covariance matrix
#' @keywords Z-matrix, starting point
Zmatrix <- function(S){
  p <- nrow(S)
  R <- stats::cov2cor(S)
  # Compute the distances. Non-positive correlations correspond to very big distances.
  D <- stats::as.dist(-log((R>0)*R+(R<=0)*1e-20))
  # use single-linkage clustering method in R
  hcl <- stats::hclust(D,method="single")
  # recover how hclust merges variables and use it to recover the corresponding ultrametric
  subs <- list()
  length(subs) <- p-1
  Z <- matrix(0,p,p)
    for (i in 1:(p-1)){
      if (hcl$merge[i,1]<0 && hcl$merge[i,2]<0) {
        subs[[i]] <- union(-hcl$merge[i,1],-hcl$merge[i,2])
        Z[-hcl$merge[i,1],-hcl$merge[i,2]]<- Z[-hcl$merge[i,2],-hcl$merge[i,1]] <- hcl$height[i]}
      else if (hcl$merge[i,1]<0 && hcl$merge[i,2]>0) {
        subs[[i]] <- union(-hcl$merge[i,1],subs[[hcl$merge[i,2]]])
        Z[-hcl$merge[i,1],subs[[hcl$merge[i,2]]]] <- hcl$height[i]
        Z[subs[[hcl$merge[i,2]]],-hcl$merge[i,1]] <- hcl$height[i]
      }
      else {
        subs[[i]] <- union(subs[[hcl$merge[i,1]]],subs[[hcl$merge[i,2]]])
        Z[subs[[hcl$merge[i,1]]],subs[[hcl$merge[i,2]]]] <- hcl$height[i]
        Z[subs[[hcl$merge[i,2]]],subs[[hcl$merge[i,1]]]] <- hcl$height[i]
          }
    }
  # Z is the corresponding ultrametric. Now compute the indiced correlation matrix
  Z <- exp(-Z)
  # finally output the corresponding covariance matrix
  return(diag(sqrt(diag(S)))%*%Z%*%diag(sqrt(diag(S))))
}


