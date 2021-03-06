---
title: "Inference for a varying coefficient regression model estimated by local adaptive grouped regularization"
author: "Wesley Brooks"
output:
  html_document:
    fig_caption: yes
---

##Things to know about the topic:




#Methods
Estimation procedure:

 + Estimate a VCR model
 + Estimate the bias in coefficient estimation
 + Draw from the sampling distribution of the coefficients, correcting for bias
 + Use the resampled coefficients to generate resampled response observations
 + From the resampled response, estimate the coefficients
 + Collect these estimates.
 
```{r import-packages, echo=FALSE, results='hide', message=FALSE} 
library(lagr)
library(dplyr)
library(knitr)
library(expm)
library(xtable)
library(doMC)
registerDoMC(3)

opts_chunk$set(echo=FALSE, message=FALSE, results='hide')
```

```{r paraboot}
read_chunk('~/git/thesis/code/inference-paper/paraboot.r')
```

```{r paraboot-run, cache=TRUE}
<<simulate-data>>
<<asymptotic-bias>>
<<empirical-bias>>
```
 
##Estimate a VCR model
The estimated value of the coefficient surface converges thus:
$$\{n h^d f(s) \}^{1/2} \left(\hat{\beta}(s) - \beta(s) - (2 \kappa_0)^{-1} \kappa_2 h^d \nabla^2 \beta(s) \right) \xrightarrow{D} N\left( 0, \kappa_0^{-2} \nu_0 \Gamma(s)^{-1} \right)$$

##Bias in coefficient estimation
The asymptotic distribution of the LAGR-estimated VCR coefficients indicates bias. The asymptotic bias is
$$(2 \kappa_0)^{-1} \kappa_2 h^d \nabla^2 \beta(s).\label{bias}$$
The bias is proportional to the second derivative of the coefficient surface. Therefore, we need to estimate $\nabla^2 \beta(s)$ in order to estimate the bias.

If the bias in estimating $\boldsymbol{\beta}(s)$ is ignored, then the biased estimate will be used for generating the parametric bootstrap draws $\boldsymbol{Y}^*_1, \dots, \boldsymbol{Y}^*_B$. Then the estimation step to reach the bootstrap estimates $\boldsymbol{\beta}^*_1(s), \dots, \boldsymbol{\beta}^*_B(s)$ will introduce another round of bias. Thus, in order use the parametric bootstrap to estimate the distribution of our estimates $\hat{\boldsymbol{\beta}}(s)$, the bias in the original estimate must be corrected.

###Bias correction
In order to estimate the bias, we must estimate the second derivative of the coefficient functions. This is done via kernel smoothing. Letting $\gamma_{1j}(s) = \nabla \hat{\beta}_j(s)$ and $\gamma_2(s) = \nabla^2 \hat{\beta}_j(s)$, the smoothed estimate of the first derivative of coefficient $j$ is
$$\nabla \hat{\beta_j}(s) = \alpha_0 \gamma_{1j}(s) + \alpha_1 \nabla^2 \gamma_{2j}(s) + \varepsilon.$$

Since we have smoothed the first derivative via a locally linear fit, the estimated second derivative is the slope of the first derivative, or $\hat{\alpha}_2(s)$. This estimate is used for estimating the bias of $\hat{\beta}_j(s)$.

This method of estimating the bias of $\hat{\beta}_j(s)$ ignores covariance does not explicitly model the covariance between the second derivatives of different coefficient functions, e.g., $\nabla^2 \hat{\beta}_1(s), \dots, \nabla^2 \hat{\beta}_p(s)$. Whether this is a problem is yet to be determined.

```{r fig.width=9, fig.height=4, fig.cap="Left to right: the intercept, $\\beta_1(s)$, and $\\beta_2(s)$ functions used to generate data for the simulation. In each plot, the true coefficient function is the solid black line, the dashed blue line is the coefficient plus the first-order asymptotic estimation bias, and the dotted red line is the coefficient plus the first- and second-order asymptotic estimation bias. The first-order estimation bias is incurred in estimating the coefficient functions from the data. The second-order estimation bias is incurred when estimating a bootstrap draw of the coefficient surface from a first-order estimate without bias correction."}
<<plot-bias>>
```

##Parametric bootstrap
Statistics are functions of the data. The distribution of a statistic is a function of the distribution of the data, and the bootstrap is a method of estimation for the data distribution. That is, we assume that $Y \sim G$ and that $F_{\boldsymbol{\theta}_0}$ is a good approximation to $G$, where $\boldsymbol{\theta}_0$ is a parameter vector and our interest is inference on $\boldsymbol{\theta}$. Then the MLE is a function of the observed data $\hat{\boldsymbol{\theta}} = T(Y)$.

The distribution of $\hat{\boldsymbol{\theta}}$ is a function of the distribution $G$, as approximated by $F_{\hat{\boldsymbol{\theta}}}$. The parametric bootstrap is used to simulate $F_{\hat{\boldsymbol{\theta}}}$, then estimation proceeds from the simulated data.

##Simulating from the estimated distribution
Note that $Y_1 \sim N(X_1^T \boldsymbol{\beta}_1, \sigma^2)$ so 
$$(X_1^T W_1 X_1)^{-1} X_1^T W_1 (Y_1 - X_1^T \boldsymbol{\beta}_1) \sim N \left(0, \sigma^2 (X_1^T W_1 X_1)^{-1} X_1^T W_1 W_1 X_1 (X_1^T W_1 X_1)^{-1}  \right).$$

From this distribution we get the MLE $\hat{\boldsymbol{\beta}}(s)$ and we can draw from the joint distribution of $\boldsymbol{\beta}(s)$.

To estimate the necessary bias correction, the second derivative of $\beta(s)$ is estimated. Since the second derivative is the slope of the slope of $\beta(s)$, we make use of the existing coefficient estimates. Leting $\nabla \hat{\beta}(s)$ be the estimated slopes of the coefficient functions (part of the MLE), we find $\nabla^2 \hat{\beta}(s)$ via a locally linear smooth of $\nabla \hat{\beta}(s)$.

Note: 
$$\beta^{*} \sim N \left(0, \sigma^2 (X_1^T W_1 X_1)^{-1} X_1^T W_1 W_1 X_1 (X_1^T W_1 X_1)^{-1}  \right).$$

Want:
$$\tilde{\beta} \xrightarrow{P} truth.$$



#Execute

##Bandwidth estimation
The bandwidth is estimated to minimize the AIC. The profile AIC is plotted in Figure \ref{fig:profile-AIC}.

```{r profile-AIC, fig.width=6, fig.height=4, fig.cap="Profile AIC trace calculated while finding the bandwidth that maximizes the AIC."}
plot(bw$trace$bw, -bw$trace$loss, type='l', bty='n', xlab="bw", ylab="-AIC", xlim=c(0,5))
```

The AIC is an approximation to the log likeliood, so we treat the profile AIC as a profile log-likelihood. Because the bandwidth is strictly positive and because of the shape of Figure ?, in this case the bandwidth is modeled with a log-normal distribution. This is an empirical Bayes procedure, under a hierarchical model with the bandwidth at a level below the coefficients. In truth, the empirical Bayes distribution for the bandwidth parameter should have some additional variability due to uncertainty in estimating the hyperparameters.

The region of greatest density includes the ten bandwidths with the smallest AIC's from the profiling step. These ten are:
```{r results='asis'}
print(xtable(bw$trace[order(bw$trace$loss)[1:10],1:2]), type='html', comment=FALSE, include.rownames=FALSE)
```



Histogram of bandwidths drawn from the estimated bandwidth distribution:

```{r fig.cap="Histogram of draws from the posterior distribution for the bandwidth parameter."}
indx = which(bw$trace$loss < (min(bw$trace$loss+20)))
max.lik = as.data.frame(bw$trace[indx,1:2])
m.bw = lm(loss ~ log(bw) + I(log(bw)^2), data=max.lik)
mu = -m.bw$coef[2] / m.bw$coef[3] / 2
sd = sqrt(1 / m.bw$coef[3])
hist(exp(rnorm(1000, mean=mu, sd=sd)), xlab='bw', ylab='Frequency', main=NA, breaks=20)
```

$\mu = \log{ \hat{h} } = `r round(mu,2)`$, $\hat{\sigma}^2 = `r signif(sd^2,2) `$

##Estimate the best fit
The means of 20 realizations of a VCR model estimated by locally linear kernel smoothing are plotted in Figure (2).

```{r realization, fig.width=9, fig.height=4, fig.cap="Left to right: the intercept, $\\beta_1(s)$, and $\\beta_2(s)$ functions, the realizable (biased) versions of the same, their estimates, and the bias-corrected estimates."}
<<plot-realization>>
```


##Make draws from the parametric bootstrap distribution
```{r paraboot-draw, cache=TRUE}
<<linked-bootstrap-sample>>
<<linked-bootstrap-estimate>>
```


