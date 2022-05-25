#!/bin/bash

set -o errexit
if [ -z $LOCALCLASSPATH ]; then
	LOCALCLASSPATH=lib/LIUM_SpkDiarization-4.2.jar
fi




#the MFCC file
features=${@:$OPTIND:1}

#get the initial segmentation file
uem=${@:$OPTIND+1:1}

#the MFCC corresponds to sphinx 12 MFCC + Energy
# sphinx=the mfcc was computed by the sphinx tools
# 1: static coefficients are present in the file
# 1: energy coefficient is present in the file
# 0: delta coefficients are not present in the file
# 0: delta energy coefficient is not present in the file
# 0: delta delta coefficients are not present in the file
# 0: delta delta energy coefficient is not present in the file
# 13: total size of a feature vector in the mfcc file
# 0:0:0: no feature normalization  
fInputDesc="sphinx,1:1:0:0:0:0,13,0:0:0"
fInputDesc="audio2sphinx,1:1:0:0:0:0,13,0:0:0"

#this variable is use in CLR/NCLR clustering and gender detection
#the MFCC corresponds to sphinx 12 MFCC + E
# sphinx=the mfcc is computed by sphinx tools
# 1: static coefficients are present in the file
# 3: energy coefficient is present in the file but will not be used
# 2: delta coefficients are not present in the file and will be computed on the fly
# 0: delta energy coefficient is not present in the file
# 0: delta delta coefficients are not present in the file
# 0: delta delta energy coefficient is not present in the file
# 13: size of a feature vector in the mfcc file
# 1:1:300:4: the MFCC are wrapped (feature warping using a sliding windows of 300 features), 
#                   next the features are centered and reduced: mean and variance are computed by segment  
fInputDescCLR="sphinx,1:3:2:0:0:0,13,1:1:300:4"
fInputDescCLR="audio2sphinx,1:3:2:0:0:0,13,1:1:300:4"


show="show"



#set the java virtual machine program
java=java

#define the directory where the results will be saved
datadir=`dirname $uem`

#define where the UBM GMM is
ubm="models/ubm.gmm"


#define where the speech / non-speech set of GMMs is
#pmsgmm=./model/sms.gmms
pmsgmm="models/sms.gmms"

#define where the silence set of GMMs is
sgmm="models/s.gmms"

#define where the gender and bandwidth set of GMMs (4 models) is
#(female studio, male studio, female telephone, male telephone) 
ggmm="models/gender.gmms"


echo "#####################################################"
echo "#   $show"
echo "#####################################################"



iseg=$datadir/$show.i.seg
pmsseg=$datadir/$show.pms.seg


adjseg=$datadir/$show.adj.h.seg

# Check the validity of the MFCC
$java -Xmx4096m -classpath $LOCALCLASSPATH fr.lium.spkDiarization.programs.MSegInit --trace --help \
 --fInputMask=$features --fInputDesc=$fInputDesc --sInputMask=$uem --sOutputMask=$datadir/show.i.seg  $show
 


# GLR-based segmentation, make small segments
$java -Xmx4096m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MSeg  --trace --help \
 --kind=FULL --sMethod=GLR  --fInputMask=$features --fInputDesc=$fInputDesc --sInputMask=$datadir/show.i.seg \
--sOutputMask=$datadir/show.s.seg  $show
 
# Linear clustering, fuse consecutive segments of the same speaker from the start to the end
$java -Xmx4096m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MClust  --trace --help \
--fInputMask=$features --fInputDesc=$fInputDesc --sInputMask=$datadir/show.s.seg  \
--sOutputMask=$datadir/show.l.seg --cMethod=l --cThr=2.5 $show
 
# Hierarchical bottom-up BIC clustering
 $java -Xmx4096m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MClust --trace --help \
--fInputMask=$features --fInputDesc=$fInputDesc --sInputMask=$datadir/show.l.seg \
--sOutputMask=$datadir/show.h.seg --cMethod=h --cThr=6 $show
 
# Initialize one speaker GMM with 8 diagonal Gaussian components for each cluster
 $java -Xmx4096m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MTrainInit --help --trace \
--nbComp=8 --kind=DIAG --fInputMask=$features --fInputDesc=$fInputDesc --sInputMask=$datadir/show.h.seg \
--tOutputMask=$datadir/show.init.gmms $show
 
# EM computation for each GMM
 $java -Xmx4096m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MTrainEM  --help  --trace \
--nbComp=8 --kind=DIAG --fInputMask=$features --fInputDesc=$fInputDesc --sInputMask=$datadir/show.h.seg \
--tOutputMask=$datadir/show.gmms  --tInputMask=$datadir/show.init.gmms  $show
 
 # Viterbi decoding using the set of GMMs trained by EM
 $java -Xmx4096m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MDecode  --trace --help \
--fInputMask=${features} --fInputDesc=$fInputDesc --sInputMask=$datadir/show.h.seg \
--sOutputMask=$datadir/show.d.seg --dPenality=250  --tInputMask=$datadir/show.gmms $show
 
 # Adjust segment boundaries near silence sections
 $java -Xmx4096m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.tools.SAdjSeg --help --trace \
 --fInputMask=$features --fInputDesc=audio2sphinx,1:1:0:0:0:0,13,0:0:0 --sInputMask=$datadir/show.d.seg \
--sOutputMask=$adjseg $show


# Split segments longer than 20s (useful for transcription)
splseg=$datadir/$show.spl.seg
$java -Xmx4096m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.tools.SSplitSeg --help \
--sFilterMask=$datadir/show.i.seg --sFilterClusterName=iS,iT,j --sInputMask=$adjseg  --sSegMaxLen=2000 --sSegMaxLenModel=2000 \
--sOutputMask=$splseg --fInputMask=$features --fInputDesc=audio2sphinx,1:3:2:0:0:0,13,0:0:0 --tInputMask=$sgmm $show




#-------------------------------------------------------------------------------
# Set gender and bandwidth
gseg=$datadir/$show.g.seg
$java -Xmx4096m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MScore --help \
 --sGender --sByCluster --fInputDesc=audio2sphinx,1:3:2:0:0:0,13,1:1:0 --fInputMask=$features --sInputMask=$splseg \
--sOutputMask=$gseg --tInputMask=$ggmm $show



# NCLR clustering
# Features contain static and delta and are centered and reduced (--fInputDesc)
c=1.7
spkseg=$datadir/$show.c.seg
$java -Xmx4096m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MClust --help --trace \
 --fInputMask=$features --fInputDesc=$fInputDescCLR --sInputMask=$gseg \
--sOutputMask=$datadir/show.seg --cMethod=ce --cThr=$c --tInputMask=$ubm \
--emCtrl=1,5,0.01 --sTop=5,$ubm --tOutputMask=$datadir/$show.c.gmm $show

