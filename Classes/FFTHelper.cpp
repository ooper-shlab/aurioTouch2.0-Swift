/*
 
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This class demonstrates how to use the Accelerate framework to take Fast Fourier Transforms (FFT) of the audio data. FFTs are used to perform analysis on the captured audio data
 
 */

#include "FFTHelper.h"

// Utility includes
#include "CABitOperations.h"


const Float32 kAdjust0DB = 1.5849e-13;


FFTHelper::FFTHelper ( UInt32 inMaxFramesPerSlice )
: mSpectrumAnalysis(NULL),
mFFTNormFactor(1.0/(2*inMaxFramesPerSlice)),
mFFTLength(inMaxFramesPerSlice/2),
mLog2N(Log2Ceil(inMaxFramesPerSlice))
{
    mDspSplitComplex.realp = (Float32*) calloc(mFFTLength,sizeof(Float32));
    mDspSplitComplex.imagp = (Float32*) calloc(mFFTLength, sizeof(Float32));
    mSpectrumAnalysis = vDSP_create_fftsetup(mLog2N, kFFTRadix2);
}


FFTHelper::~FFTHelper()
{
    vDSP_destroy_fftsetup(mSpectrumAnalysis);
    free (mDspSplitComplex.realp);
    free (mDspSplitComplex.imagp);
}


void FFTHelper::ComputeFFT(Float32* inAudioData, Float32* outFFTData)
{
	if (inAudioData == NULL || outFFTData == NULL) return;
    
    //Generate a split complex vector from the real data
    vDSP_ctoz((COMPLEX *)inAudioData, 2, &mDspSplitComplex, 1, mFFTLength);
    
    //Take the fft and scale appropriately
    vDSP_fft_zrip(mSpectrumAnalysis, &mDspSplitComplex, 1, mLog2N, kFFTDirection_Forward);
    vDSP_vsmul(mDspSplitComplex.realp, 1, &mFFTNormFactor, mDspSplitComplex.realp, 1, mFFTLength);
    vDSP_vsmul(mDspSplitComplex.imagp, 1, &mFFTNormFactor, mDspSplitComplex.imagp, 1, mFFTLength);
    
    //Zero out the nyquist value
    mDspSplitComplex.imagp[0] = 0.0;
    
    //Convert the fft data to dB
    vDSP_zvmags(&mDspSplitComplex, 1, outFFTData, 1, mFFTLength);
    
    //In order to avoid taking log10 of zero, an adjusting factor is added in to make the minimum value equal -128dB
    vDSP_vsadd(outFFTData, 1, &kAdjust0DB, outFFTData, 1, mFFTLength);
    Float32 one = 1;
    vDSP_vdbcon(outFFTData, 1, &one, outFFTData, 1, mFFTLength, 0);
}
