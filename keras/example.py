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

MATLAB_FILE = sys.argv[1]
MODEL_FILE = MATLAB_FILE[:-4]+'.hdf5'

## PARAMETERS
WINDOW_SIZE = 150    # equals 250ms at 600Hz sampling rate
lr = 0.001           # the learning rate
batchsize = 256      # the batch size
epochs = 25          # the number of epochs




## CREATE EEG2Code CNN Model
def construct_model(windowSize,numberChannels):
	model = Sequential()
	model.add(Permute((3,2,1), input_shape=(windowSize,numberChannels,1)))
	# layer1
	model.add(Conv2D(16, kernel_size=(numberChannels, 1), padding='valid', strides=(1, 1), data_format='channels_first', activation='relu'))
	model.add(BatchNormalization(axis=1, scale=False, center=False))
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
	return model


# LOAD MATLAB FILE
def load_matfile(filename,windowSize):
	mat_contents = sio.loadmat(filename)
	train_data_x = np.array(mat_contents['train_data_x'])
	train_data_y = np.array(mat_contents['train_data_y'])
	test_data_x  = np.array(mat_contents['test_data_x'])
	test_data_y  = np.array(mat_contents['test_data_y'])
	
	channels = np.array([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,25,26,27,28,29,30,31,32])-1
	train_data_x = train_data_x[:,channels,:]
	test_data_x = test_data_x[:,channels,:]

	# split train data to 250ms (150 sample) windows
	data_x_train = []
	data_y_train = []
	for ii in range(train_data_x.shape[0]):
		trialdata = train_data_x[ii,:,:].squeeze().transpose()
		data_x_windows = np.zeros((train_data_x.shape[2],windowSize,train_data_x.shape[1]))
		for t in range(windowSize):
			data_x_windows[:,t,:] = np.roll(trialdata,-t,axis=0)
		data_x_windows = data_x_windows[0:(data_x_windows.shape[0]-windowSize),:,:]
		bitdata = train_data_y[ii,:].squeeze().transpose()
		for t in range(data_x_windows.shape[0]):
			data_x_train.append(data_x_windows[t,:,:].squeeze())
			data_y_train.append([bitdata[t],abs(bitdata[t]-1)])
	data_x_train = np.array(data_x_train);
	data_y_train = np.array(data_y_train);
			
	# split train data to train and validation set (equal size)
	data_x_train = data_x_train.reshape(-1,data_x_train.shape[1],data_x_train.shape[2],1)
	data_y_train = data_y_train.reshape(-1,2)
	if (len(data_x_train) % 2) != 0:
		data_x_train = data_x_train[:-1]
		data_y_train = data_y_train[:-1]
	x_split = np.split(data_x_train, 2)
	y_split = np.split(data_y_train, 2)
	data_x_train = x_split[0]
	data_y_train = y_split[0]
	data_x_val   = x_split[1]
	data_y_val   = y_split[1]
	
	# split test data to 250ms (150 sample) windows
	data_x_test = np.zeros((test_data_x.shape[0],test_data_x.shape[2]-windowSize,windowSize,test_data_x.shape[1]))
	data_y_test = test_data_y[:,0:test_data_y.shape[1]-windowSize];
	for ii in range(test_data_x.shape[0]):
		trialdata = test_data_x[ii,:,:].squeeze().transpose()
		data_x_windows = np.zeros((test_data_x.shape[2],windowSize,test_data_x.shape[1]))
		for t in range(windowSize):
			data_x_windows[:,t,:] = np.roll(trialdata,-t,axis=0)
		data_x_windows = data_x_windows[0:(data_x_windows.shape[0]-windowSize),:,:]
		data_x_test[ii,:,:,:] = data_x_windows.reshape(-1,data_x_windows.shape[0],data_x_windows.shape[1],data_x_windows.shape[2])
	data_x_test = np.array(data_x_test);
	
	return data_x_train,data_y_train,data_x_val,data_y_val,data_x_test,data_y_test

def downsample(arr, n):
    end =  n * int(len(arr)/n)
    return np.mean(arr[:end].reshape(-1, n), 1)
	
	

## LOAD data
(data_x_train,data_y_train,data_x_val,data_y_val,data_x_test,data_y_test) = load_matfile(MATLAB_FILE,WINDOW_SIZE)

## TRAIN EEG2Code CNN Model
if not os.path.isfile(MODEL_FILE):
	model = construct_model(data_x_train.shape[1],data_x_train.shape[2])
	adam = keras.optimizers.Adam(lr=lr)
	model.compile(loss='categorical_crossentropy',optimizer=adam,metrics=['accuracy'])
	history = model.fit(data_x_train, data_y_train, batch_size=batchsize, epochs=epochs, validation_data=(data_x_val, data_y_val), callbacks = [keras.callbacks.ModelCheckpoint(MODEL_FILE, monitor='val_loss', verbose=0, save_best_only=True, save_weights_only=False, mode='auto', period=1)])
model = load_model(MODEL_FILE)

## EEG2Code prediction
for ii in range(data_x_test.shape[0]):
	data_x_test_run = data_x_test[ii,:,:,:].squeeze()
	data_y_test_run = data_y_test[ii,:].squeeze()
	
	# do EEG2Code prediction (sample-wise)
	preddata = model.predict(data_x_test_run.reshape(-1,data_x_test_run.shape[1],data_x_test_run.shape[2],1))
	# downsample to bit-wise (10 samples per bit)
	preddata = downsample(preddata[:,0].squeeze(),10)
	# transform model prediction to predicted stimulation pattern
	predpattern = np.round(preddata)
	# compare predicted stimulation pattern to real stimulation pattern
	realpattern = np.round(downsample(data_y_test_run,10))
	accuracy = np.mean(predpattern==realpattern)
	print (accuracy)