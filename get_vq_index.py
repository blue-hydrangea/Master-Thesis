from numpy import array
from ast import literal_eval
from scipy.cluster.vq import vq
import sys

cluster_nr = sys.argv[1]
feats_txt = sys.argv[2]
cluster_centroids = sys.argv[3]
word = sys.argv[4]

cluster_ids_name = "clustering/"+word+"_"+cluster_nr+"_cluster_ids.txt"
cluster_ids = open(cluster_ids_name,"w")

observations=[]
clusters=[]

with open(feats_txt) as feats_file:
	for line in feats_file:
		mfcc_vec=literal_eval(line)
		observations.append(mfcc_vec)

with open(cluster_centroids) as clusters_file:
	for line in clusters_file:
		cluster_vec=literal_eval(line)
		clusters.append(cluster_vec)

features  = array(observations)
codebook = array(clusters)

cluster=vq(features,codebook)

cluster_ids.write(str(cluster[0]))

cluster_ids.close()
