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
SAMPLE_SIZE = numChannels*8
WINDOW_SIZE = windowSize*SAMPLE_SIZE;
BUFFER_SIZE = 2*WINDOW_SIZE
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
	byterecv = conn.recv(2*WINDOW_SIZE)
	bytedata += byterecv
	if len(bytedata) >= WINDOW_SIZE :
		trimbytes = len(bytedata)%SAMPLE_SIZE
		if trimbytes > 0:
			doubledata = np.frombuffer(bytedata[:-trimbytes])
		else:
			doubledata = np.frombuffer(bytedata)
		if (doubledata[len(doubledata)-numChannels:]==np.zeros(numChannels)).all():
			bytedata = ''
			doubledata = doubledata[:-numChannels]
			if len(doubledata) < WINDOW_SIZE/8:
				continue
			eegdata = doubledata.reshape(len(doubledata)/numChannels,numChannels)
		else:
			bytedata = bytedata[len(doubledata)*8-(WINDOW_SIZE-SAMPLE_SIZE):]
			eegdata = doubledata.reshape(len(doubledata)/numChannels,numChannels)
		data_x_timelag = np.zeros((eegdata.shape[0],windowSize,eegdata.shape[1]))
		for t in range(windowSize):
			data_x_timelag[:,t,:] = np.roll(eegdata,-t,axis=0)
		data_x_timelag = data_x_timelag[0:(data_x_timelag.shape[0]-windowSize+1),:,:]
		pred = EEG2CodeKeras.classify(model,data_x_timelag);
		pred = np.array(pred)
		conn.sendall(pred)
	if not byterecv: break
	 
conn.close()
