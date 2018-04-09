from numpy import array
from ast import literal_eval
from scipy.cluster.vq import vq, kmeans, whiten
import sys

feats_txt = sys.argv[1]
cluster_nr = sys.argv[2]

cluster_centroid_name = "clustering/centroids/"+str(cluster_nr)+"_cluster_centroids.txt"
cluster_centroids = open(cluster_centroid_name,"w")

observations=[]

with open(feats_txt) as feats_file:
	for line in feats_file:
		mfcc_vec=literal_eval(line)
		observations.append(mfcc_vec)

features = array(observations)
codebook = kmeans(features,int(cluster_nr))

for code in codebook:
	cluster_centroids.write(str(code))

cluster_centroids.close()
