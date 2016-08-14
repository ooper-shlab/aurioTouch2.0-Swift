/*
 
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This class handles buffering of audio data that is shared between the view and audio controller
 
 */

#include "BufferManager.h"


#define min(x,y) (x < y) ? x : y


BufferManager::BufferManager( UInt32 inMaxFramesPerSlice ) :
mDisplayMode(0 /*aurioTouchDisplayModeOscilloscopeWaveform*/),
mDrawBuffers(),
mDrawBufferIndex(0),
mCurrentDrawBufferLen(kDefaultDrawSamples),
mFFTInputBuffer(NULL),
mFFTInputBufferFrameIndex(0),
mFFTInputBufferLen(inMaxFramesPerSlice),
mHasNewFFTData(0),
mNeedsNewFFTData(0),
mFFTHelper(NULL)
{
    for(UInt32 i=0; i<kNumDrawBuffers; ++i) {
        mDrawBuffers[i] = (Float32*) calloc(inMaxFramesPerSlice, sizeof(Float32));
    }
    
    mFFTInputBuffer = (Float32*) calloc(inMaxFramesPerSlice, sizeof(Float32));
    mFFTHelper = new FFTHelper(inMaxFramesPerSlice);
    OSAtomicIncrement32Barrier(&mNeedsNewFFTData);
}


BufferManager::~BufferManager()
{
    for(UInt32 i=0; i<kNumDrawBuffers; ++i) {
        free(mDrawBuffers[i]);
        mDrawBuffers[i] = NULL;
    }
    
    free(mFFTInputBuffer);
    delete mFFTHelper; mFFTHelper = NULL;
}


void BufferManager::CopyAudioDataToDrawBuffer( Float32* inData, UInt32 inNumFrames )
{
    if (inData == NULL) return;
    
    for (UInt32 i=0; i<inNumFrames; i++)
    {
        if ((i+mDrawBufferIndex) >= mCurrentDrawBufferLen)
        {
            CycleDrawBuffers();
            mDrawBufferIndex = -i;
        }
        mDrawBuffers[0][i + mDrawBufferIndex] = inData[i];
    }
    mDrawBufferIndex += inNumFrames;
}


void BufferManager::CycleDrawBuffers()
{
    // Cycle the lines in our draw buffer so that they age and fade. The oldest line is discarded.
	for (int drawBuffer_i=(kNumDrawBuffers - 2); drawBuffer_i>=0; drawBuffer_i--)
		memmove(mDrawBuffers[drawBuffer_i + 1], mDrawBuffers[drawBuffer_i], mCurrentDrawBufferLen);
}


void BufferManager::CopyAudioDataToFFTInputBuffer( Float32* inData, UInt32 numFrames )
{
    UInt32 framesToCopy = min(numFrames, mFFTInputBufferLen - mFFTInputBufferFrameIndex);
    memcpy(mFFTInputBuffer + mFFTInputBufferFrameIndex, inData, framesToCopy * sizeof(Float32));
    mFFTInputBufferFrameIndex += framesToCopy * sizeof(Float32);
    if (mFFTInputBufferFrameIndex >= mFFTInputBufferLen) {
        OSAtomicIncrement32(&mHasNewFFTData);
        OSAtomicDecrement32(&mNeedsNewFFTData);
    }
}


void BufferManager::GetFFTOutput( Float32* outFFTData )
{
    mFFTHelper->ComputeFFT(mFFTInputBuffer, outFFTData);
    mFFTInputBufferFrameIndex = 0;
    OSAtomicDecrement32Barrier(&mHasNewFFTData);
    OSAtomicIncrement32Barrier(&mNeedsNewFFTData);
}
