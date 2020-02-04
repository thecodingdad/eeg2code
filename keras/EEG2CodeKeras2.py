from __future__ import division
import keras
import os
import sys
import numpy as np
import scipy.io as sio

from keras import optimizers
from keras import initializers
from keras.models import load_model
from keras.models import Sequential
from keras.layers import Conv2D, MaxPooling2D, Permute, Flatten, Dense, BatchNormalization, Activation, Dropout

def trainOnMatfile(matfile,modelfile,windowSize,targetdelays):
	if not os.path.isfile(modelfile):
		x_train,y_train,x_val,y_val,x_test,x_trainnc = load_traindata(matfile,windowSize,targetdelays)
		numChannels = x_train.shape[2];
		model = train(modelfile,x_train,y_train,x_val,y_val)
		
		pred = classify(model,x_test)
		np.savetxt(matfile[:-4]+"_train_pred.csv", pred, delimiter=",")
		pred = classify(model,x_trainnc)
		np.savetxt(matfile[:-4]+"_trainnc_pred.csv", pred, delimiter=",")
	else:
		numChannels = get_channels(matfile)
		model = load_model(modelfile)
	return model,numChannels


def train(filename,x_train,y_train,x_val,y_val):
	if not os.path.isfile(filename):
		# model parameter
		lr = 0.001
		batchsize = 256
		epochs = 25

		model = construct_model(x_train.shape[1],x_train.shape[2])
		adam = keras.optimizers.Adam(lr=lr)
		model.compile(loss='categorical_crossentropy',optimizer=adam,metrics=['accuracy'])
		history = model.fit(x_train, y_train, batch_size=batchsize, epochs=epochs, validation_data=(x_val, y_val), callbacks = [keras.callbacks.ModelCheckpoint(filename, monitor='val_loss', verbose=0, save_best_only=True, save_weights_only=False, mode='auto', period=1)])
	
	model = load_model(filename)
	
	return model;

# input: keras model, and test data (windowSize x Channels)
def classify(model,x_test):
	x_test = x_test.reshape(-1,x_test.shape[1],x_test.shape[2],1)
	pred = model.predict(x_test)
	return pred[:,0];
	
def get_channels(filename):
	print('Load mat file')
	mat_contents = sio.loadmat(filename)
	usedchannels = np.array(mat_contents['usedchannels'])[0]
	numChannels = usedchannels.size
	return numChannels


def load_traindata(filename,windowSize,targetdelays):
	print('Load mat file')
	mat_contents = sio.loadmat(filename)

	# extract matlab struct
	train_data_x = np.array(mat_contents['train_data_x'])
	train_data_y = np.array(mat_contents['train_data_y'])
	trainnc_data_x = np.array(mat_contents['trainnc_data_x'])
	trainnc_data_y = np.array(mat_contents['trainnc_data_y'])
	usedchannels = np.array(mat_contents['usedchannels'])[0]
	targetdelays = np.array(targetdelays)

	print('Splitting train data to windows using the following channels')
	print(usedchannels)
	data_x_train = []
	data_y_train = []
	data_x_test = []
	for ii in range(train_data_x.shape[0]):
		realtarget = ii % 32
		targetshift = targetdelays[realtarget]
		trialdata = train_data_x[ii,usedchannels-1,:].squeeze().transpose()
		trialdatashifted = np.roll(trialdata,-targetshift,axis=0)

		data_x_timelag = np.zeros((trialdata.shape[0],windowSize,len(usedchannels)))
		data_x_timelagshifted = np.zeros((trialdatashifted.shape[0],windowSize,len(usedchannels)))
		for t in range(windowSize):
			data_x_timelag[:,t,:] = np.roll(trialdata,-t,axis=0)
			data_x_timelagshifted[:,t,:] = np.roll(trialdatashifted,-t,axis=0)

		data_x_timelag = data_x_timelag[0:(data_x_timelag.shape[0]-windowSize),:,:]
		data_x_timelagshifted = data_x_timelagshifted[0:(data_x_timelagshifted.shape[0]-windowSize),:,:]
		bitdata = train_data_y[ii,realtarget,:].squeeze().transpose()
		for t in range(data_x_timelag.shape[0]):
			data_x_train.append(data_x_timelagshifted[t,:,:].squeeze())
			data_x_test.append(data_x_timelag[t,:,:].squeeze())
			data_y_train.append([bitdata[t],abs(bitdata[t]-1)])
			
	# split train and validation set
	(x_train,y_train,x_val,y_val) = split_data(np.array(data_x_train),np.array(data_y_train))
	data_x_test = np.array(data_x_test)
			
	data_x_trainnc = []
	for ii in range(trainnc_data_x.shape[0]):
		realtarget = ii % 32
		targetshift = targetdelays[realtarget]
		trialdata = trainnc_data_x[ii,usedchannels-1,:].squeeze().transpose()

		data_x_timelag = np.zeros((trialdata.shape[0],windowSize,len(usedchannels)))
		for t in range(windowSize):
			data_x_timelag[:,t,:] = np.roll(trialdata,-t,axis=0)

		data_x_timelag = data_x_timelag[0:(data_x_timelag.shape[0]-windowSize),:,:]
		for t in range(data_x_timelag.shape[0]):
			data_x_trainnc.append(data_x_timelag[t,:,:].squeeze())

	data_x_trainnc = np.array(data_x_trainnc)

	print('done.')
	
	return x_train,y_train,x_val,y_val,data_x_test,data_x_trainnc


def split_data(x_train,y_train):
	print ('Splitting train data to train set and validation set')
	x_train = x_train.reshape(-1,x_train.shape[1],x_train.shape[2],1)
	y_train = y_train.reshape(-1,2)
	# Split data to train and validation set
	if (len(x_train) % 2) != 0:
		x_train = x_train[:-1]
		y_train = y_train[:-1]
	x_split = np.split(x_train, 2)
	y_split = np.split(y_train, 2)
	# train set
	x_train = x_split[0]
	y_train = y_split[0]
	# validation set
	x_val = x_split[1]
	y_val = y_split[1]
	print ('done.')
	
	return x_train,y_train,x_val,y_val
	
def construct_model(windowSize,numChannels):
	# construct sequential model
	model = Sequential()
	# permute input so that it is as in EEG Net paper
	model.add(Permute((3,2,1), input_shape=(windowSize,numChannels,1)))
	# layer1
	model.add(Conv2D(16, kernel_size=(numChannels, 1), padding='valid', strides=(1, 1), data_format='channels_first', activation='relu'))
	model.add(BatchNormalization(axis=1, scale=False, center=False))
	#model.add(Permute((2,1,3)))
	model.add(Activation('relu'))
	model.add(MaxPooling2D(pool_size=(2, 2),strides=(2, 2),padding='same'))
	# layer2
	model.add(Conv2D(8,kernel_size=(1, 64),data_format='channels_first',padding='same'))
	model.add(BatchNormalization(axis=1,scale=False, center=False))
	model.add(Activation('relu'))
	model.add(MaxPooling2D(pool_size=(2, 2),strides=(2, 2),padding='same'))
	model.add(Dropout(0.5))
	# layer3
	model.add(Conv2D(4,kernel_size=(5, 5),data_format='channels_first',padding='same'))
	model.add(BatchNormalization(axis=1,scale=False,center=False))
	model.add(Activation('relu'))
	model.add(MaxPooling2D(pool_size=(2, 2), data_format='channels_first',padding='same'))
	model.add(Dropout(0.5))
	# layer4
	model.add(Flatten())
	model.add(Dense(1024, activation='relu'))
	model.add(Dropout(0.5))
	# layer5
	model.add(Dense(2, activation='softmax'))
	#print(model.summary())
	return model