library(lagr)
library(spgwr)
library(ggplot2)
library(doMC)
library(sp)
library(plyr)
library(maptools)

registerDoMC(6)
data(georgia)

bw = lagr.tune(PctPov ~ PctRural+PctBach+PctEld+PctFB+PctBlack, data=gSRDF, verbose=TRUE, longlat=TRUE, bw.type='knn', range=c(0,0.3), kernel=epanechnikov, varselect.method="wAIC", bwselect.method="AICc")


gm = lagr(PctPov ~ PctRural+PctBach+PctEld+PctFB+PctBlack, data=gSRDF, bw=bw, longlat=TRUE, verbose=TRUE, bw.type='knn', kernel=epanechnikov, varselect.method="AIC")
cc = sapply(gm[['fits']], function(x) x[['model']][['results']][['big.avg']])
gSRDF@data$.PctRural = cc[2,]

is0 = gSRDF
slot(is0, "polygons") <- lapply(slot(is0, "polygons"), checkPolygonsHoles)
is1 <- unionSpatialPolygons(is0, as.character(is0$ID))

g.points = fortify(is1, region="ID")
names(g.points)[7] = "ID"
g.df = join(g.points, gSRDF@data, by="ID")
ggplot(g.df, aes(long,lat, group=ID, fill=.PctRural)) + geom_polygon()