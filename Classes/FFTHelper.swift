//
//  FFTHelper.swift
//  aurioTouch
//
//  Created by 開発 on 2015/1/30.
//
//
/*

     File: FFTHelper.h
     File: FFTHelper.cpp
 Abstract: This class demonstrates how to use the Accelerate framework to take Fast Fourier Transforms (FFT) of the audio data. FFTs are used to perform analysis on the captured audio data

  Version: 2.0

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (C) 2014 Apple Inc. All Rights Reserved.


 */


import Accelerate


class FFTHelper {
    
    private var mSpectrumAnalysis: FFTSetup
    private var mDspSplitComplex: DSPSplitComplex = DSPSplitComplex(realp: nil, imagp: nil)
    private var mFFTNormFactor: Float32
    private var mFFTLength: vDSP_Length
    private var mLog2N: vDSP_Length
    
    
    private final var kAdjust0DB: Float32 = 1.5849e-13
    
    
    init(maxFramesPerSlice inMaxFramesPerSlice: Int) {
        mSpectrumAnalysis = nil
        mFFTNormFactor = 1.0/Float32(2*inMaxFramesPerSlice)
        mFFTLength = vDSP_Length(inMaxFramesPerSlice)/2
        mLog2N = vDSP_Length(log2Ceil(UInt32(inMaxFramesPerSlice)))
        mDspSplitComplex.realp = UnsafeMutablePointer.alloc(Int(mFFTLength))
        mDspSplitComplex.imagp = UnsafeMutablePointer.alloc(Int(mFFTLength))
        mSpectrumAnalysis = vDSP_create_fftsetup(mLog2N, FFTRadix(kFFTRadix2))
    }
    
    
    deinit {
        vDSP_destroy_fftsetup(mSpectrumAnalysis)
        mDspSplitComplex.realp.dealloc(mFFTLength.l)
        mDspSplitComplex.imagp.dealloc(mFFTLength.l)
    }
    
    
    func computeFFT(inAudioData: UnsafePointer<Float32>, outFFTData: UnsafeMutablePointer<Float32>) {
        if inAudioData == nil || outFFTData == nil { return }
        
        //Generate a split complex vector from the real data
        vDSP_ctoz(UnsafePointer(inAudioData), 2, &mDspSplitComplex, 1, mFFTLength)
        
        //Take the fft and scale appropriately
        vDSP_fft_zrip(mSpectrumAnalysis, &mDspSplitComplex, 1, mLog2N, FFTDirection(kFFTDirection_Forward))
        vDSP_vsmul(mDspSplitComplex.realp, 1, &mFFTNormFactor, mDspSplitComplex.realp, 1, mFFTLength)
        vDSP_vsmul(mDspSplitComplex.imagp, 1, &mFFTNormFactor, mDspSplitComplex.imagp, 1, mFFTLength)
        
        //Zero out the nyquist value
        mDspSplitComplex.imagp[0] = 0.0
        
        //Convert the fft data to dB
        vDSP_zvmags(&mDspSplitComplex, 1, outFFTData, 1, mFFTLength)
        
        //In order to avoid taking log10 of zero, an adjusting factor is added in to make the minimum value equal -128dB
        vDSP_vsadd(outFFTData, 1, &kAdjust0DB, outFFTData, 1, mFFTLength)
        var one: Float32 = 1
        vDSP_vdbcon(outFFTData, 1, &one, outFFTData, 1, mFFTLength, 0)
    }
}