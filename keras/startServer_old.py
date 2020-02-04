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

# start tcpip server
BUFFER_SIZE = windowSize*numChannels*8;
HOST = '0.0.0.0'
PORT = 5000

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind((HOST, PORT))
s.listen(1)
print ("waiting for response from client at port ",PORT)
(conn, addr) = s.accept()
print ('Connected by', addr)
bytedata = ''
while True:
	byterecv = conn.recv(BUFFER_SIZE)
	bytedata += byterecv
	if len(bytedata) >= BUFFER_SIZE :
		doubledata = np.frombuffer(bytedata[:BUFFER_SIZE])
		bytedata = bytedata[BUFFER_SIZE:]
		eegdata = np.expand_dims(doubledata.reshape(numChannels,windowSize).transpose(),axis=0)
		pred = EEG2CodeKeras.classify(model,eegdata);
		pred = np.array(float(pred))
		conn.sendall(pred)
	if not byterecv: break
	 
conn.close()
