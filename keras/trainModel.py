import os
import sys
import socket
import EEG2CodeKeras
import numpy as np

MATLAB_FILE = sys.argv[1]
MODEL_FILE = MATLAB_FILE[:-4]+'.hdf5'

targetdelays = [2,2,2,2,2,2,2,2,4,4,4,4,4,4,4,4,6,6,6,6,6,6,6,6,9,9,9,9,9,9,9,9]
windowSize = 150;

# train model
(model,numChannels) = EEG2CodeKeras.trainOnMatfile(MATLAB_FILE,MODEL_FILE,windowSize,targetdelays)
