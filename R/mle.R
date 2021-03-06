fit.zicmp.reg <- function(y, X, S, W, beta.init, gamma.init, zeta.init,
	max, optim.control = list(maxit = 150))
{
	start <- Sys.time()
	u <- as.integer(y == 0)
	d1 <- ncol(X)
	d2 <- ncol(S)
	d3 <- ncol(W)
	n <- length(y)
	qq <- d1 + d2 + d3

	if (is.null(beta.init)) { beta.init <- rep(0, d1) }
	if (is.null(gamma.init)) { gamma.init <- rep(0, d2) }
	if (is.null(zeta.init)) { zeta.init <- rep(0, d3) }

	tx <- function(par) {
		list(
			beta = par[1:d1],
			gamma = par[1:d2 + d1],
			zeta = par[1:d3 + d1 + d2]
		)
	}

	loglik <- function(par) {
		theta <- tx(par)
		lambda <- exp(X %*% theta$beta)
		nu <- exp(S %*% theta$gamma)
		p <- plogis(W %*% theta$zeta)
		z <- computez(lambda, nu, max)

		t(u) %*% log(p*z + (1-p)) + t(1 - u) %*% (log(1-p) +
			y*log(lambda) - nu*lgamma(y+1)) - sum(log(z))
	}

	optim.control$fnscale = -1
	par.init <- c(beta.init, gamma.init, zeta.init)
	res <- optim(par.init, loglik, method = 'L-BFGS-B',
		control = optim.control, hessian = TRUE)
	H <- res$hessian

	theta.hat <- list(
		beta = res$par[1:d1],
		gamma = res$par[1:d2 + d1],
		zeta = res$par[1:d3 + d1 + d2]
	)

	FIM <- fim.zicmp.reg(X, S, W, theta.hat$beta, theta.hat$gamma,
		theta.hat$zeta, max = max)
	V <- solve(FIM)

	lambda.hat <- exp(X %*% theta.hat$beta)
	nu.hat <- exp(S %*% theta.hat$gamma)
	p.hat <- plogis(W %*% theta.hat$zeta)
	mu.hat <- expected.y(lambda.hat, nu.hat, p.hat, max)
	mse <- mean( (y - mu.hat)^2 )

	loglik <- res$value
	elapsed.sec <- as.numeric(Sys.time() - start, type = "sec")

	res <- list(theta.hat = theta.hat, V = V, H = H, FIM = FIM, opt.res = res,
		elapsed.sec = elapsed.sec, loglik = loglik, n = n)
	return(res)
}

fit.cmp.reg <- function(y, X, S, beta.init, gamma.init,
	max, optim.control = list(maxit = 150))
{
	start <- Sys.time()
	u <- as.integer(y == 0)
	d1 <- ncol(X)
	d2 <- ncol(S)
	n <- length(y)
	qq <- d1 + d2

	if (is.null(beta.init)) { beta.init <- rep(0, d1) }
	if (is.null(gamma.init)) { gamma.init <- rep(0, d2) }

	tx <- function(par) {
		list(
			beta = par[1:d1],
			gamma = par[1:d2 + d1]
		)
	}

	loglik <- function(par) {
		theta <- tx(par)
		lambda <- exp(X %*% theta$beta)
		nu <- exp(S %*% theta$gamma)
		z <- computez(lambda, nu, max)
		sum(y*log(lambda) - nu*lgamma(y+1) - log(z))
	}

	optim.control$fnscale = -1
	par.init <- c(beta.init, gamma.init)
	res <- optim(par.init, loglik, method = 'L-BFGS-B',
		control = optim.control, hessian = TRUE)
	H <- res$hessian

	theta.hat <- list(
		beta = res$par[1:d1],
		gamma = res$par[1:d2 + d1]
	)

	W <- matrix(1, n, 1)
	FIM.full <- fim.zicmp.reg(X, S, W = W, theta.hat$beta, theta.hat$gamma,
		zeta = -Inf, max = max)
	FIM <- FIM.full[1:(d1+d2), 1:(d1+d2)]
	V <- solve(FIM)

	lambda.hat <- exp(X %*% theta.hat$beta)
	nu.hat <- exp(S %*% theta.hat$gamma)
	p.hat <- 0
	mu.hat <- expected.y(lambda.hat, nu.hat, p.hat, max)
	mse <- mean( (y - mu.hat)^2 )

	loglik <- res$value
	elapsed.sec <- as.numeric(Sys.time() - start, type = "sec")

	res <- list(theta.hat = theta.hat, V = V, H = H, FIM = FIM, opt.res = res,
		elapsed.sec = elapsed.sec, loglik = loglik, n = n)
	return(res)
}

fit.zip.reg <- function(y, X, W, beta.init, zeta.init,
	max, optim.control = list(maxit = 150))
{
	start <- Sys.time()
	u <- as.integer(y == 0)
	d1 <- ncol(X)
	d3 <- ncol(W)
	n <- length(y)
	qq <- d1 + d3

	if (is.null(beta.init)) { beta.init <- rep(0, d1) }
	if (is.null(zeta.init)) { zeta.init <- rep(0, d3) }

	tx <- function(par) {
		list(
			beta = par[1:d1],
			zeta = par[1:d3 + d1]
		)
	}

	loglik <- function(par) {
		theta <- tx(par)
		lambda <- exp(X %*% theta$beta)
		p <- plogis(W %*% theta$zeta)
		sum(u*log(p + (1-p)*exp(-lambda)) + (1-u)*log(1-p) +
			(1-u)*(y*log(lambda) - lambda - lgamma(y+1)))
	}

	optim.control$fnscale = -1
	par.init <- c(beta.init, zeta.init)
	res <- optim(par.init, loglik, method = 'L-BFGS-B',
		control = optim.control, hessian = TRUE)
	H <- res$hessian

	theta.hat <- list(
		beta = res$par[1:d1],
		zeta = res$par[1:d3 + d1]
	)

	FIM <- fim.zicmp.reg(X, S = matrix(1, n, 1), W, theta.hat$beta,
		gamma = 0, theta.hat$zeta, max = max)
	V <- solve(FIM)

	lambda.hat <- exp(X %*% theta.hat$beta)
	nu.hat <- rep(0, n)
	p.hat <- plogis(W %*% theta.hat$zeta)
	mu.hat <- expected.y(lambda.hat, nu.hat, p.hat, max)
	mse <- mean( (y - mu.hat)^2 )

	loglik <- res$value
	elapsed.sec <- as.numeric(Sys.time() - start, type = "sec")

	res <- list(theta.hat = theta.hat, V = V, H = H, FIM = FIM, opt.res = res,
		elapsed.sec = elapsed.sec, loglik = loglik, n = n)
	return(res)
}

expected.y <- function(lambda, nu, p, max)
{
	z <- computez(lambda, nu, max=max)
	dzdlambda <- computez.prodj(lambda, nu, max=max)/lambda
	dlogzdlambda <- dzdlambda / z
	(1-p) * lambda * dlogzdlambda	
}

expected.y.reg <- function(X, S, W, beta, gamma, zeta, max)
{
	lambda <- exp(X %*% beta)
	nu <- exp(S %*% gamma)
	p <- plogis(W %*% zeta)
	expected.y(lambda, nu, p, max)
}
