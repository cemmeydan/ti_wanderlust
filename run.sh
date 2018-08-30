#!/usr/local/bin/python

import os
import wishbone
import os
import sys
import json
import pandas as pd

import time
checkpoints = {}


#   ____________________________________________________________________________
#   Load data                                                               ####
p = json.load(open("/ti/input/params.json", "r"))

# get start cell(s)
start_cell = json.load(open("/ti/input/start_id.json"))[0]

# get markers if given
if os.path.exists("/ti/input/features_id.json"):
  markers = json.load(open("/ti/input/features_id.json"))
else:
  markers = "~"

checkpoints["method_afterpreproc"] = time.time()

#   ____________________________________________________________________________
#   Create trajectory                                                       ####
# normalise data
scdata = wishbone.wb.SCData.from_csv("/ti/input/counts.csv", data_type='sc-seq', normalize=p["normalise"])
scdata.run_pca()
scdata.run_diffusion_map(knn=p["knn"], epsilon=p["epsilon"], n_diffusion_components=p["n_diffusion_components"], n_pca_components=p["n_pca_components"], markers=markers)

# check waypoints parameter to be lower than # cells
if p["num_waypoints"] > scdata.data.shape[0]:
  p["num_waypoints"] = scdata.data.shape[0]

# run wishbone
wb = wishbone.wb.Wishbone(scdata)
wb.run_wishbone(start_cell=start_cell, components_list=list(range(p["n_diffusion_components"])), num_waypoints=int(p["num_waypoints"]), branch=False, k=p["k"])

checkpoints["method_aftermethod"] = time.time()

#   ____________________________________________________________________________
#   Process output & save                                                   ####
# pseudotime
pseudotime = wb.trajectory.reset_index()
pseudotime.columns = ["cell_id", "pseudotime"]
pseudotime.to_csv("/ti/output/pseudotime.csv", index=False)

# dimred
dimred = wb.scdata.diffusion_eigenvectors
dimred.index.name = "cell_id"
dimred.reset_index().to_csv("/ti/output/dimred.csv", index=False)

# cell ids
cell_ids = pd.DataFrame({
  "cell_ids": dimred.index
})
cell_ids.to_csv("/ti/output/cell_ids.csv", index=False)

# timings
json.dump(checkpoints, open("/ti/output/timings.json", "w"))
