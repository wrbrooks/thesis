library(lagr)
library(mgcv)
library(dplyr)
library(doMC)

registerDoMC(7)

set.seed(11181982)

#Set constants:
B1 = 1
B = 50
n = 100

#Simulate data:
f0 = function(x) {-0.2*x^4 + x^3 + 0.7*(x-1)^2 - 4*(x-2) + 1}
f1 = function(x) {cos(x)}
f2 = function(x) {0.1*sin(x)}
tt = seq(0, 5, len=n)


f0.second.derivative = function(x) {-2.4*x^2 + 6*x + 1.4}
f1.second.derivative = function(x) {-cos(x)}
f2.second.derivative = function(x) {-0.1*sin(x)}

fitted = list()
resid = list()
coefs = list()

empirical.bias.0 = list()
empirical.bias.1 = list()
empirical.bias.2 = list()

for (b in 1:B1) {
print(b)
    X1 = rnorm(n, mean=3, sd=2)
    X2 = rnorm(n, mean=3, sd=2)
    y = f0(tt) + X1*f1(tt) + X2*f2(tt) + rnorm(n)
    df = data.frame(y, x1=X1, x2=X2, t=tt)

    m = lagr(y~x1+x2, data=df, family='gaussian', coords='t', varselect.method='AICc', kernel=epanechnikov, bw.type='knn', bw=0.2, verbose=TRUE, lagr.convergence.tol=0.005, lambda.min.ratio=0.01, n.lambda=80)
    
    W = list()
    for (i in 1:n) {
        h = m[['fits']][[i]][['bw']]
        w = epanechnikov(abs(tt-tt[i]), h)
        W[[i]] = diag(w)
    }
    
    fitted[[b]] = sapply(m[['fits']], function(x) tail(x[['fitted']],1))
    resid[[b]] = df$y - fitted[[b]]
    coefs[[b]] = t(sapply(m[['fits']], function(x) x[['model']][['beta']][,ncol(x[['model']][['beta']])]))
}
bias.0 = f0.second.derivative(tt) * sapply(m[['fits']], function(x) x[['bw']]) / 10
bias.1 = f1.second.derivative(tt) * sapply(m[['fits']], function(x) x[['bw']]) / 10
bias.2 = f2.second.derivative(tt) * sapply(m[['fits']], function(x) x[['bw']]) / 10



#Plot multiple realizations of the means: resampling should look something like this(?)
yy = range(c(f2(tt), sapply(coefs, function(x) x[,3])))
plot(x=tt,y=f2(tt), bty='n', xlab='t', ylab='Intercept', ylim=yy, type='l')
for (b in 1:B) {
    par(new=TRUE)
    #Subtract the bias as it appears from the rate of change of the first derivative:
    plot(x=tt, y=coefs[[b]][,3], bty='n', ann=FALSE, yaxt='n', xaxt='n', ylim=yy, type='l', col='red')
}
par(new=TRUE)
plot(x=tt, y=f2(tt) + bias.2, bty='n', ann=FALSE, yaxt='n', xaxt='n', ylim=yy, type='l', col='blue', lty=2, lwd=2)
par(new=TRUE)
plot(x=tt, y=coefs[[b]][,3] - empirical.bias.2[[b]], bty='n', ann=FALSE, yaxt='n', xaxt='n', ylim=yy, type='l', col='green', lty=2, lwd=2)





#Linked bootstrap draws:
beta.star.1 = list()
Y.star.1 = list()
X = as.matrix(cbind(1, X1, X2))

for (j in 1:B) {
    cat(paste("j is ", j, "\n", sep=""))
    beta.star.1[[j]] = matrix(NA,6,0)
    y.hat.seed = as.matrix(rnorm(6))
    
    for (i in 1:n) {
        Sigma = with(summary(m[['fits']][[i]][['model']][['adamodel']]), cov.unscaled * dispersion)[1:6,1:6]
        beta.star.1[[j]] = cbind(beta.star.1[[j]], (coefs[[1]][i,] + (sqrtm(Sigma) %*% y.hat.seed)))
    }
    beta.star.1[[j]] = t(beta.star.1[[j]][1:3,]) - empirical.bias[[1]]
    Y.star.1[[j]] = sapply(1:n, function(k) t(X[k,]) %*% beta.star.1[[j]][k,]) + rnorm(n, 0, sd=sd(resid[[1]]))
}

for (b in 1:B) {
    print(b)
    df.b = df
    df.b$y = Y.star.1[[b]]
    
    m.b = lagr(y~x1+x2, data=df.b, family='gaussian', coords='t', varselect.method='AIC', kernel=epanechnikov, bw.type='knn', bw=0.2, verbose=TRUE, lagr.convergence.tol=0.005, lambda.min.ratio=0.01, n.lambda=80)
    coefs.boot[[b]] = t(sapply(m.b$fits, function(x) x$coef))
}


#sd by Efron method (nonparametric delta method):
sd.boot = list()
for (i in 1:n) {
    #Only 49 resamples ran last time:
    B = 49
    
    t.b = sapply(coefs.boot, function(x) x[i,]) %>% t
    t.mean = matrix(rep(colMeans(t.b),each=B),B,3)
    B.b = (sapply(beta.star.1, function(x) x[i,]) %>% t)[1:B,]
    
    cov.b = t(B.b) %*% (t.b-t.mean) / B
    V.b = t(B.b) %*% B.b / B
    sd.boot[[i]] = sqrtm(t(cov.b) %*% solve(V.b) %*% cov.b)
}


#png("/Users/wesley/git/thesis/writeup/paraboot/figures/paraboot-est.png", width=7, height=3, units='in', res=150)
layout(matrix(1:3,1,3))
#confidence from paraboot:
sapply(coefs.boot, function(x) x[,1]) %>% range -> yy
sapply(coefs.boot, function(x) x[,1]) %>% apply(1, function(y) quantile(y, 0.05)) %>% plot(x=tt, type='l', xlab='t', ylab=expression(beta[0]), ylim=yy, bty='n')
par(new=TRUE)
sapply(coefs.boot, function(x) x[,1]) %>% apply(1, function(y) quantile(y, 0.95)) %>% plot(x=tt, type='l', ylim=yy, ann=FALSE, bty='n', xaxt='n', yaxt='n')
par(new=TRUE)
plot(x=tt, y=f0(tt)+bias.0, ylim=yy, type='l', col='red', ann=FALSE, bty='n', xaxt='n', yaxt='n')

#confidence from paraboot:
sapply(coefs.boot, function(x) x[,2]) %>% range -> yy
sapply(coefs.boot, function(x) x[,2]) %>% apply(1, function(y) quantile(y, 0.05)) %>% plot(x=tt, type='l', xlab='t', ylab=expression(beta[1]), ylim=yy, bty='n')
par(new=TRUE)
sapply(coefs.boot, function(x) x[,2]) %>% apply(1, function(y) quantile(y, 0.95)) %>% plot(x=tt, type='l', ylim=yy, ann=FALSE, bty='n', xaxt='n', yaxt='n')
par(new=TRUE)
plot(x=tt, y=f1(tt)+bias.1, ylim=yy, type='l', col='red', ann=FALSE, bty='n', xaxt='n', yaxt='n')

#confidence from paraboot:
sapply(coefs.boot, function(x) x[,3]) %>% range -> yy
sapply(coefs.boot, function(x) x[,3]) %>% apply(1, function(y) quantile(y, 0.05)) %>% plot(x=tt, type='l', xlab='t', ylab=expression(beta[2]), ylim=yy, bty='n')
par(new=TRUE)
sapply(coefs.boot, function(x) x[,3]) %>% apply(1, function(y) quantile(y, 0.95)) %>% plot(x=tt, type='l', ylim=yy, ann=FALSE, bty='n', xaxt='n', yaxt='n')
par(new=TRUE)
plot(x=tt, y=f2(tt)+bias.2, ylim=yy, type='l', col='red', ann=FALSE, bty='n', xaxt='n', yaxt='n')

#dev.off()




#confidence from Efron:
sapply(coefs.boot, function(x) x[,1]) %>% range -> yy
(sapply(coefs.boot, function(x) x[,1]) %>% rowMeans - 1.96*sapply(sd.boot, function(x) x[1,1])) %>% plot(x=tt, type='l', xlab='t', ylab=expression(beta[0]), ylim=yy, bty='n')
par(new=TRUE)
(sapply(coefs.boot, function(x) x[,1]) %>% rowMeans + 1.96*sapply(sd.boot, function(x) x[1,1])) %>% plot(x=tt, type='l', ylim=yy, ann=FALSE, bty='n', xaxt='n', yaxt='n')
par(new=TRUE)
plot(x=tt, y=f0(tt)+bias.0, ylim=yy, type='l', col='red', ann=FALSE, bty='n', xaxt='n', yaxt='n')
par(new=TRUE)
sapply(coefs.boot, function(x) x[,1]) %>% rowMeans %>% plot(x=tt, ylim=yy, col='blue', lty=2, ann=FALSE, xaxt='n', yaxt='n', bty='n', type='l')


#confidence from Efron:
sapply(coefs.boot, function(x) x[,2]) %>% range -> yy
(sapply(coefs.boot, function(x) x[,2]) %>% rowMeans - 1.96*sapply(sd.boot, function(x) x[2,2])) %>% plot(x=tt, type='l', xlab='t', ylab=expression(beta[1]), ylim=yy, bty='n')
par(new=TRUE)
(sapply(coefs.boot, function(x) x[,2]) %>% rowMeans + 1.96*sapply(sd.boot, function(x) x[2,2])) %>% plot(x=tt, type='l', ylim=yy, ann=FALSE, bty='n', xaxt='n', yaxt='n')
par(new=TRUE)
plot(x=tt, y=f1(tt)+bias.1, ylim=yy, type='l', col='red', ann=FALSE, bty='n', xaxt='n', yaxt='n')
par(new=TRUE)
sapply(coefs.boot, function(x) x[,2]) %>% rowMeans %>% plot(x=tt, ylim=yy, col='blue', lty=2, ann=FALSE, xaxt='n', yaxt='n', bty='n', type='l')


#confidence from Efron:
sapply(coefs.boot, function(x) x[,3]) %>% range -> yy
(coefs[[1]][,3] - 1.96*sapply(sd.boot, function(x) x[3,3])) %>% plot(x=tt, type='l', xlab='t', ylab=expression(beta[2]), ylim=yy, bty='n')
par(new=TRUE)
(coefs[[1]][,3] + 1.96*sapply(sd.boot, function(x) x[3,3])) %>% plot(x=tt, type='l', ylim=yy, ann=FALSE, bty='n', xaxt='n', yaxt='n')
par(new=TRUE)
plot(x=tt, y=f2(tt)+bias.2, ylim=yy, type='l', col='red', ann=FALSE, bty='n', xaxt='n', yaxt='n')





#Plot draws from the linked bootstrap: TOO SMOOTH
yy2 = sapply(beta.star.1, function(x) range(x[2,])) %>% range
plot(x=tt,y=f1(tt), bty='n', xlab='t', ylab='Intercept', ylim=yy2, type='l')
par(new=TRUE)
plot(x=tt, y=coefs[[B]][,2], bty='n', ann=FALSE, yaxt='n', xaxt='n', ylim=yy2, type='l', col='blue')
par(new=TRUE)
plot(x=tt, y=f1(tt) + bias.1, bty='n', ann=FALSE, yaxt='n', xaxt='n', ylim=yy2, type='l', col='blue', lty=2)
for (b in 1:B) {
    par(new=TRUE)
    plot(x=tt, y=beta.star.1[[b]][2,], bty='n', ann=FALSE, yaxt='n', xaxt='n', ylim=yy2, type='l', col='red')
}



#Now a full distribution bootstrap (too rough?):
Sigma = list()
for (i in 1:n) {
    Sigma[[i]] = with(summary(m[['fits']][[i]][['model']][['adamodel']]), cov.unscaled * dispersion)[1:3,1:3]
}

SS = bdiag(Sigma)
for (i in 1:(n-1)) {
    X.i = cbind(1, X1, X2)
    
    for (j in (i+1):n) {
        X.j = cbind(1, X1, X2)
        scale = sqrt(summary(m[['fits']][[i]][['model']][['adamodel']])$dispersion *
                         summary(m[['fits']][[j]][['model']][['adamodel']])$dispersion)
        
        unscaled = summary(m[['fits']][[i]][['model']][['adamodel']])$cov.unscaled[1:3,1:3] %*%
            t(X.i) %*% sqrt(W[[i]] %*% W[[j]]) %*% 
            X.j %*% summary(m[['fits']][[j]][['model']][['adamodel']])$cov.unscaled[1:3,1:3]
        
        SS[((i-1)*3+1):(3*i), ((j-1)*3+1):(3*j)] =
            SS[((j-1)*3+1):(3*j), ((i-1)*3+1):(3*i)] = scale * unscaled
    }
}

SS.posdef = SS %*% t(SS)
SS.eigen = eigen(SS.posdef)

sqSS = SS.eigen$vectors %*% diag(SS.eigen$values^(1/4)) %*% t(SS.eigen$vectors)

#Draw from a joint parametric distribution:
beta.star.3 = list()
beta.star.4 = list()
for (k in 1:B) {
    #beta.star.3[[k]] = (t(coefs) + matrix(sqSS %*% rep(rnorm(6),n), 6, n))
    beta.star.4[[k]] = (t(coefs[[B]][,1:3]) + matrix(sqSS %*% rnorm(3*n), 3, n))
}

yy2 = sapply(beta.star.4, function(x) range(x[1,])) %>% range
plot(x=tt,y=f0(tt), bty='n', xlab='t', ylab='Intercept', ylim=yy2, type='l')
par(new=TRUE)
plot(x=tt, y=coefs[[B]][,1], bty='n', ann=FALSE, yaxt='n', xaxt='n', ylim=yy2, type='l', col='blue')
for (b in 1:B) {
    par(new=TRUE)
    plot(x=tt, y=beta.star.4[[b]][1,], bty='n', ann=FALSE, yaxt='n', xaxt='n', ylim=yy2, type='l', col='red')
}



g1 = gam(resid[[B]]~s(tt, k=50))
s2 = g1$sig2

plot(x=tt, y=resid[[B]], bty='n', xlab='t', ylab='residual')
par(new=TRUE)
plot(x=tt, y=fitted(g1), type='l', ylim=range(resid), ann=FALSE, xaxt='n', yaxt='n', bty='n')
