dir.der = function(x, p) {
    grad = gr(p)[1:100]
    t(x) %*% grad
}
    
dir.der2 = function(x, p) {
    grad2 = gr2(p[1:100])
    t(x) %*% grad2 %*% x
}    

gr = function(x) {
    g = rep(0, 102)
    c = as.matrix(x[1:100])
    d = as.matrix(x[101:102])
    g[1:100] = (t(Q1)%*%T1 + t(Q2)%*%T2)%*%d + (t(Q1)%*%Q1 + t(Q2)%*%Q2 + lambda*Q0)%*%c - t(Q1)%*%obs - t(Q2)%*%obs.
    g[101:102] = (t(T1)%*%T1 + t(T2)%*%T2)%*%d + (t(T1)%*%Q1 + t(T2)%*%Q2)%*%c - t(T1)%*%obs - t(T2)%*%obs.
    
    g = as.vector(2*g)
    g
}

gr2 = function(x) {
    t(Q1)%*%Q1 + t(Q2)%*%Q2 + lambda*Q0
}

heq = function(x) {
    c = as.matrix(x[1:100])
    t(F1) %*% c
}

heq.jac = function(x) {
    c = as.matrix(x[1:100])
    cbind(t(F1), 0, 0)
}

fn = function(x) {
    c = as.matrix(x[1:100])
    d = as.matrix(x[101:102])
    
    sum((obs - Q1%*%c - T1%*%d)^2) + sum((obs. - Q2%*%c - T2%*%d)^2) + lambda*t(c)%*%Q0%*%c
}

lambda=0.01
F2 %*% solve(t(F2) %*% (Q1 + lambda*QtI%*%Q0) %*% F2) %*% t(F2) %*% obs -> c
solve(R) %*% t(F1) %*% (obs - (Q1 - lambda* QtI%*%Q0) %*% c) -> d
p = c(c,d) 

i=0
fn.old=Inf
norma = Inf
normp = t(p)%*%p
while (norma/normp > 1e-6) {
    i=i+1
    fn.old = fn(p)
    (diag(rep(1,100)) - T0%*%solve(t(T0)%*%T0)%*%t(T0)) %*% gr(p)[1:100] -> a
    norma = (t(a)%*%a)[1]
    a = a / norma #normalize a to unit length
    a / dir.der2(a,p)[1] -> aa
    c - aa -> c
    
    d = solve(t(T1)%*%T1 + t(T2)%*%T2) %*% (t(T1)%*%obs + t(T2)%*%obs. - t(T1)%*%Q1%*%c - t(T2)%*%Q2%*%c)
    p = c(c,d)
    normp = t(p)%*%p
    cat(paste(i, ": ", norma, "\n", sep=""))
}





c = p[1:100]
d = p[101:102]
f0.smooth.hat = (Q1 %*% c + T1 %*% d) 
f0.hat = (Q0 %*% c + T0 %*% d) 

plot(f0.smooth.hat, type='l', bty='n', x=tt, ylim=range(f0(xx)), lwd=2)
par(new=TRUE)
#plot(f0.smooth, x=tt, bty='n', ann=FALSE, xaxt='n', yaxt='n', col='red', ylim=range(f0(xx)), type='l')
plot(obs, x=tt, bty='n', ann=FALSE, xaxt='n', yaxt='n', col='red', ylim=range(f0(xx)), type='l', lwd=2)
par(new=TRUE)
plot(f0.hat, x=tt, bty='n', ann=FALSE, xaxt='n', yaxt='n', col='blue', ylim=range(f0(xx)), type='l', lwd=2)
par(new=TRUE)
plot(f0(xx), x=tt, bty='n', ann=FALSE, xaxt='n', yaxt='n', lty=2, ylim=range(f0(xx)), type='l', lwd=2)

