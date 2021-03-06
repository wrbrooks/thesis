library(expm)
library(lagr)
library(doMC)
library(MASS)
library(dplyr)

registerDoMC(7)

source("scratch/inference/simulate-data.r")

#bw = lagr.tune(Y~X1+X2+X3+X4, data=sim, family='gaussian', coords=c('loc.x','loc.y'), longlat=FALSE, varselect.method='wAIC', bwselect.method="AIC", kernel=epanechnikov, bw.type='knn', verbose=FALSE, n.lambda=100, lagr.convergence.tol=0.005, tol.bw=0.0005)
#bw$trace[order(bw$trace[,1]),][,c(1,2)] -> trace
#bw.range = range(trace[trace[,2]<min(trace[,2])+10,1])
#bw.range=c(0.13, 0.27)

#Number of bootstrap draws:
B = 50

bootstrap.data = sim
df = list()
ll = list()
aic = list()
coef.distribution = list()
is.zero = list()
Sigma = list()
paraboot.coefs = list()
hh = seq(0.1, 0.3, len=21)#trace[,1]
for (j in 1:length(hh)) {
    h = hh[j]
    model = lagr(Y~X1+X2+X3+X4, data=sim, family='gaussian', coords=c('loc.x','loc.y'), longlat=FALSE, varselect.method='AIC', bw=h, kernel=epanechnikov, bw.type='knn', verbose=FALSE, n.lambda=100, lagr.convergence.tol=0.005)
    
    df.natural = sum(sapply(model[['model']], function(x) {
        crit = x[['tunelist']][['criterion']]
        crit.weights = exp(-0.5*(min(crit)-crit)**2)
        sum((1+x[['model']][['results']][['df']]) * crit.weights) / sum(crit.weights)
    })) / (h*nrow(sim))
    
    fit = sapply(model[['model']], function(x) {
        crit = x[['tunelist']][['criterion']]
        crit.weights = exp(-0.5*(min(crit)-crit)**2)
        sum(x[['tunelist']][['localfit']] * crit.weights) / sum(crit.weights)
    })
    
    s2 = sum((fit - sim$Y)**2) / (nrow(sim) - df.natural)
    
    Sigma[[j]] = list()
    paraboot.coefs[[j]] = list()
    bootstrap.seed = sapply(1:B, function(m) return(matrix(rnorm(15, 0, 1))))
    err = sapply(1:B, function(m) return(matrix(rnorm(nrow(sim), 0, sqrt(s2)))))
    bootstrap.response = matrix(NA, 0, B)
    for (i in 1:nrow(sim)) {
        mu = model[['model']][[i]][['model']][['LS.coefs']][1:5]
        S2 = 4/3/pi * model[['model']][[i]][['model']][['results']][['full.model.cov']]
        Sigma[[j]][[i]] = sqrtm(S2)
        bootstrap.coefs = t((Sigma[[j]][[i]] %*% bootstrap.seed) + mu)
        paraboot.coefs[[j]][[i]] = bootstrap.coefs
        eta = bootstrap.coefs[,1:5] %*% matrix(as.numeric(c(1, sim[i,2:5])))
        bootstrap.response = rbind(bootstrap.response,
            rnorm(n=length(eta), mean=eta, sd=sqrt(s2)))
    }
    bootstrap.response = cbind(sim$Y, bootstrap.response)
    
    bootstrap.model = list()
    df[[j]] = vector()
    ll[[j]] = vector()
    aic[[j]] = vector()
    fl = sim[133,c('loc.x', 'loc.y')]
    for (i in 1:(B+1)) {
        cat(paste(i, "\n", sep=""))
        bootstrap.data$Y = bootstrap.response[,i]
        bootstrap.model[[i]] = lagr(Y~X1+X2+X3+X4, data=bootstrap.data, coords=c('loc.x','loc.y'), longlat=FALSE, varselect.method='wAIC', bw=h, kernel=epanechnikov, bw.type='knn', verbose=FALSE, n.lambda=100, lagr.convergence.tol=0.005)

        df[[j]] = c(df[[j]], sum(sapply(bootstrap.model[[i]][['model']], function(x) tail(x[['tunelist']][['df-local']], 1))))
        fitted = sapply(bootstrap.model[[i]][['model']], function(x) {
            #crit = x[['tunelist']][['criterion']]
            #crit.weights = exp(-0.5*(min(crit)-crit)**2)
            crit.weights = x[['model']][['results']][['wAIC']]
            sum(x[['tunelist']][['localfit']] * crit.weights) / sum(crit.weights)
        })
        ll[[j]] = c(ll[[j]], sum((fitted - bootstrap.response[,i])^2))
        aic[[j]] = c(aic[[j]], tail(ll[[j]], 1) + 2*tail(df[[j]], 1))
    }

    
    
    is.zero[[j]] = data.frame()
    coef.distribution[[j]] = data.frame()
    for (k in 1:nrow(sim)) {
        is.zero.temp = matrix(NA,15,0)
        coef.distribution.temp = matrix(NA,15,0)
        
        for (i in 1:(B+1)) {
            coefs = bootstrap.model[[i]][['model']][[k]][['coef']]
            bootstrap.model[[i]][['model']][[k]][['model']][['results']][['wAIC']] -> wAIC
            if (!is.null(coefs)) {
                #is.zero.temp = cbind(is.zero.temp, matrix(as.double(coefs==0), nrow(coefs), ncol(coefs)) %*% exp(0.5*(min(crit)-crit)) / sum(exp(0.5*(min(crit)-crit))))
                #coef.distribution.temp = cbind(coef.distribution.temp, as.double(coefs %*% exp(0.5*(min(crit)-crit)) / sum(exp(0.5*(min(crit)-crit)))))
                is.zero.temp = cbind(is.zero.temp, matrix(as.double(coefs==0), nrow(coefs), ncol(coefs)) %*% as.matrix(wAIC))
                coef.distribution.temp = cbind(coef.distribution.temp, as.double(coefs %*% as.matrix(wAIC)))
            } else {
                is.zero.temp = cbind(is.zero.temp, NA)
                coef.distribution.temp = cbind(coef.distribution.temp, NA)
            }
        }
        
        is.zero.temp = as.data.frame(is.zero.temp)
        coef.distribution.temp = as.data.frame(coef.distribution.temp)

        is.zero.temp = cbind(bootstrap.data[k,'loc.x'], bootstrap.data[k,'loc.y'], h, c("Intercept", "B1", "B2", "B3", "B4", "Intercept-x", "B1-x", "B2-x", "B3-x", "B4-x", "Intercept-y", "B1-y", "B2-y", "B3-y", "B4-y"), is.zero.temp)
        coef.distribution.temp = cbind(bootstrap.data[k,'loc.x'], bootstrap.data[k,'loc.y'], h, c("Intercept", "B1", "B2", "B3", "B4", "Intercept-x", "B1-x", "B2-x", "B3-x", "B4-x", "Intercept-y", "B1-y", "B2-y", "B3-y", "B4-y"), coef.distribution.temp)
        
        is.zero[[j]] = rbind(is.zero[[j]], is.zero.temp)
        coef.distribution[[j]] = rbind(coef.distribution[[j]], coef.distribution.temp)
    }
    
    colnames(is.zero[[j]]) = c("x", "y", "bandwidth", "coefficient", paste("rep", 1:(B+1), sep=" "))
    colnames(coef.distribution[[j]]) = c("x", "y", "bandwidth", "coefficient", paste("rep", 1:(B+1), sep=" "))
    
    #Following Efron (2014):
    #V = 4/3/pi * model[['model']][[133]][['model']][['results']][['full.model.cov']][1:5,1:5]
    #cov(t(coef.distribution), cc[[133]])
}

#For means:
p = 15
bw.specific.coefs = matrix(0, p*nrow(sim), 0)
natural.aic = sapply(aic, function(x) x[1])
indx = (0:195)*15 + 2 #(beta_1)
for (l in 1:length(hh)) {
    bw.specific.coefs = cbind(bw.specific.coefs, rowMeans(as.matrix(coef.distribution[[l]][,5:(B+5)])))
}
natural.aic.weight = matrix(exp(-(natural.aic-min(natural.aic))/2))
natural.aic.weight = natural.aic.weight / sum(natural.aic.weight)
model.avg.coefs = bw.specific.coefs %*% natural.aic.weight

matplot(B1 %>% matrix(20,20), border=NA, show.legend=TRUE, axes=FALSE, xlab=expression(beta[1]), ylab=NA, cex.lab=2, xrange=zz)

#For means:
p = 15
bw.specific.zeros = matrix(0, p*nrow(sim), 0)
natural.aic = sapply(aic, function(x) x[1])
indx = (0:195)*15 + 2 #(beta_1)
for (l in 1:length(hh)) {
    bw.specific.zeros = cbind(bw.specific.zeros, rowMeans(as.matrix(is.zero[[l]][,5:(B+5)])))
}
natural.aic.weight = matrix(exp(-(natural.aic-min(natural.aic))/2))
natural.aic.weight = natural.aic.weight / sum(natural.aic.weight)
model.avg.zeros = bw.specific.zeros %*% natural.aic.weight




#For sd's:
p = 15
bw.specific.coef.sd = matrix(0, p*nrow(sim), 0)
natural.aic = sapply(aic, function(x) x[1])
indx = (0:195)*15 + 2 #(beta_1)
for (l in 1:length(hh)) {
    bw.specific.coef.sd = cbind(bw.specific.coef.sd, rowMeans(as.matrix(coef.distribution[[l]][,5:(B+5)])))
}
natural.aic.weight = matrix(exp(-(natural.aic-min(natural.aic))/2))
natural.aic.weight = natural.aic.weight / sum(natural.aic.weight)
model.avg.sd = bw.specific.coef.sd %*% natural.aic.weight


