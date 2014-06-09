library("e1071")
library("klaR")
library("rpart")

# prepare data to read from csv files
frame_files <- lapply(sys.frames(), function(x) x$ofile)
frame_files <- Filter(Negate(is.null), frame_files)
PATH <- dirname(frame_files[[length(frame_files)]])
breastPath = paste(PATH,"/breast.csv",sep="")
winePath = paste(PATH,"/wine.csv",sep="")
irisPath = paste(PATH,"/iris.csv",sep="")

readCsvData = function(filepath,colname="",colnr=0){
  isHeader = !colname==""
  data = read.csv(filepath, header=isHeader) 
  if (isHeader) {
    colnr = match(colname,colnames(data))
  } else {
    colname =  colnames(data)[colnr]
  }
  
  list(data,colnr,colname)
}

#-----------utils functions-----------

#vec01 = vector of {0;1}
#convert vec01 to collection of column numbers
columnsToClusterNatural <- function (myvec){
  colnum = 1
  returnvec = c()
  for(i in myvec)
  {
    if(i == 1)
    {
      returnvec = append(returnvec,colnum)
    }
    colnum = colnum + 1
  }
  returnvec
}

splitDataset = function (mydata, percent){
  smp_size <- floor(percent * nrow(mydata))
  
  ## set the seed to make your partition reproductible
  set.seed(123)
  train_ind <- sample(seq_len(nrow(mydata)), size = smp_size)
  
  train <- mydata[train_ind, ]
  test <- mydata[-train_ind, ]
  list("train"=train,"test"=test)
}

#input: data, vec01
#output: data with columns indicated by vec01
extractCols <- function (mydata, myvec) {
  mydata[columnsToClusterNatural(myvec)]
}

getColNumber = function (data,colName){
  colNumber = match(colName,colnames(data))
  colNumber
}

deleteColumnByName = function (data,colName){
  new_data = data[,-getColNumber(data,colName)]
} 

appendColumn = function (data,column){
  data[,colnames(column)[1]]=column
  data
}

selectRandom = function(vecTable){
  rand = sample(1:ncol(vecTable),1)
  vecTable[,rand]
}

generateNeighbours = function(vec01, k){
  len01 = length(vec01)
  returnvec = array(0,c(len01,choose(len01,k)))
  x = combn(length(vec01),k)
  veccount = 1
  for(i in seq(1,ncol(x))) 
  { 
    newvec = vec01
    for(j in seq(1,nrow(x)))
    {
      newvec[x[j,i]] = (1 - vec01[x[j,i]])
    }
    if (sum(newvec)==sum(vec01))
    {
      #append vector
      returnvec[,veccount] = newvec
      veccount = veccount + 1
    }
  }
  returnvec=returnvec[,1:veccount-1,drop=FALSE]
  returnvec
  
}

randomVector = function(dim, atrCount){
  vect = array(dim=dim,data=0)
  vect[sample(dim,atrCount)]=1
  vect
}

callMethod = function(method,indata,colName,vect){
  column = indata[colName]
  workdata=deleteColumnByName(indata,colName)
  workdata = extractCols(workdata,vect)
  workdata = appendColumn(workdata,column)
  method(workdata,colName) 
}

selectBest = function(neigh,indata,method,colName) {
  bestVector = c()
  bestScore = 0
  neighsize = 
  if(ncol(neigh)<1)
  {
       return(list(bestVector,bestScore))
  }
  for(i in 1:ncol(neigh))
  {
    vect = neigh[,i]
    score = callMethod(method,indata,colName,vect)
    if(score > bestScore)
    {   
      bestScore = score
      bestVector = vect
    }        
  }
  list(bestVector,bestScore)
}

#-----------score functions-----------

SVM = function(mdata,colName){
  formul = as.formula(paste(colName,"~."))
  colNumber = match(colName,colnames(mdata))
  splitdata = splitDataset(mdata,0.75)
  model = svm(formul, splitdata$train)
  zmienna=predict(model, splitdata$test[-colNumber])
  tryCatch({zmienna=round(zmienna)},error=function(e){})
  quality=sum(as.integer(splitdata$test[,colNumber]==zmienna))/nrow(splitdata$test)
  quality
}

NB = function(mdata,colName){
  formul = as.formula(paste(colName,"~."))
  colNumber = match(colName,colnames(mdata))
  #f= NaiveBayes.formula
  splitdata = splitDataset(mdata,0.75)
  dropped = splitdata$train[,colName,drop=TRUE]
  droppedFactor = as.factor(dropped)
  model = NaiveBayes(x=splitdata$train[-colNumber],grouping=droppedFactor)
  zmienna=predict(model, splitdata$test[-colNumber])$class
  tryCatch({zmienna=round(zmienna)},error=function(e){})
  quality=sum(as.integer(splitdata$test[,colNumber]==zmienna))/nrow(splitdata$test)
  quality
}

DT = function(mdata,colName){
  formul = as.formula(paste(colName,"~."))
  colNumber = match(colName,colnames(mdata))
  splitdata = splitDataset(mdata,0.75)
  model = rpart(formul,splitdata$train)
  zmienna=predict(model,splitdata$test)
  tryCatch(
      {
          zmienna = colnames(zmienna)[apply(zmienna,1,which.max)]
      },
      error=function(e){
          zmienna=round(zmienna)
      })
  quality=sum(as.integer(splitdata$test[,colNumber]==zmienna))/nrow(splitdata$test)
  quality
}

#-----------optimization functions-----------

MC = function(indata,colName,atrCount,iterCount, method){
  best=-1
  for (i in 1:iterCount) {
    vect = randomVector(ncol(indata)-1,atrCount)
    qual=callMethod(method,indata,colName,vect)
    if (qual>best){
      best=qual
      bestvect=vect
    }
  }
  list(bestvect,best)
}

RW = function(indata,colName,atrCount,iterCount, method){
  best=-1
  vect = randomVector(ncol(indata)-1,atrCount)
  for (i in 1:iterCount) {
    qual=callMethod(method,indata,colName,vect) 
    if (qual>best){
      best=qual
      bestvect=vect
    }
    neigh = generateNeighbours(vect,2)
    if (length(neigh) == 0) {
        break
    }
    vect = selectRandom(neigh)
  }
  list(bestvect,best)
}

VNS = function(indata,colName,atrCount,maxDist, method){
  column = indata[colName]
  
  bestvect = randomVector(ncol(indata)-1,atrCount)
  best= callMethod(method,indata,colName,bestvect)
  
    
  stop = FALSE
  while(!stop)
  {
    k = 2
    repeat{
      neigh = generateNeighbours(bestvect,k)
      yList = selectBest(neigh,indata,method,colName) #TODO
      yvect = yList[[1]]
      ybest = yList[[2]]
      #until
      if(ybest > best) #save found solution and start with with k = 1
      {
        best=ybest
        bestvect=yvect
        break
      }
      k = k + 2
      if(k > maxDist || k>2*atrCount)
      {
        #if inside it means that no y was better and maximum radius was reached
        stop = TRUE
        break
      }
    }
  }
  list(bestvect,best)
}

MOW = function (datacsv,method,strategy,strategyParam){
  workdata = datacsv[[1]]
  colNumber = datacsv[[2]]
  colName = datacsv[[3]]
  
  quality=c()
  atrCount=c()
  for(i in 1:(ncol(workdata)-1)) { #-1 for
    print(i)
    wd=workdata
    result = strategy(wd,colName,i,strategyParam,method)
    atrCount=append(atrCount,i)
    quality=append(quality,result[[2]])
    print(result[[2]])
  }
  margin = 0.1*(max(quality)-min(quality))
  print((quality))
  plot(atrCount,quality,
       ylim=c(min(quality),max(quality))) 
}


dataWCSV = readCsvData(winePath,"Alcohol")
dataICSV = readCsvData(irisPath,"Species")
dataBCSV = readCsvData(breastPath,colnr=2)


testD = function(method,strategy,strategyParam) {
   print("Iris:")
   MOW(dataICSV,method,strategy,strategyParam)
   print("Wine:")
   MOW(dataWCSV,method,strategy,strategyParam)
   #print("Breast:")
   #MOW(dataBCSV,method,strategy,strategyParam)
}

testDM = function(strategy,strategyParam) {
  print("DT:")
  testD(DT,strategy,strategyParam)
  print("NB:")
  testD(NB,strategy,strategyParam)
  print("SVM:")
  testD(SVM,strategy,strategyParam)
}

