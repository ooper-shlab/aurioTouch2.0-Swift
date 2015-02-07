//
//  BufferManager.swift
//  aurioTouch
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/30.
//
//
/*

     File: BufferManager.h
     File: BufferManager.cpp
 Abstract: This class handles buffering of audio data that is shared between the view and audio controller
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

import AudioToolbox
import libkern


let kNumDrawBuffers = 12
let kDefaultDrawSamples = 1024


class BufferManager {
    
    var displayMode: AudioController.aurioTouchDisplayMode
    
    
    private(set) var drawBuffers: UnsafeMutablePointer<UnsafeMutablePointer<Float32>>
    
    var currentDrawBufferLength: Int
    
    var hasNewFFTData: Bool {return mHasNewFFTData != 0}
    var needsNewFFTData: Bool {return mNeedsNewFFTData != 0}
    
    var FFTOutputBufferLength: Int {return mFFTInputBufferLen / 2}
    
    private var mDrawBufferIndex: Int
    
    private var mFFTInputBuffer: UnsafeMutablePointer<Float32>
    private var mFFTInputBufferFrameIndex: Int
    private var mFFTInputBufferLen: Int
    private var mHasNewFFTData: Int32   //volatile
    private var mNeedsNewFFTData: Int32 //volatile
    
    private var mFFTHelper: FFTHelper
    
    
    init(maxFramesPerSlice inMaxFramesPerSlice: Int) {
        displayMode = .OscilloscopeWaveform
        drawBuffers = UnsafeMutablePointer.alloc(Int(kNumDrawBuffers))
        mDrawBufferIndex = 0
        currentDrawBufferLength = kDefaultDrawSamples
        mFFTInputBuffer = nil
        mFFTInputBufferFrameIndex = 0
        mFFTInputBufferLen = inMaxFramesPerSlice
        mHasNewFFTData = 0
        mNeedsNewFFTData = 0
        for i in 0..<kNumDrawBuffers {
            drawBuffers[Int(i)] = UnsafeMutablePointer.alloc(Int(inMaxFramesPerSlice))
        }
        
        mFFTInputBuffer = UnsafeMutablePointer.alloc(Int(inMaxFramesPerSlice))
        mFFTHelper = FFTHelper(maxFramesPerSlice: inMaxFramesPerSlice)
        OSAtomicIncrement32Barrier(&mNeedsNewFFTData)
    }
    
    
    deinit {
        for i in 0..<kNumDrawBuffers {
            drawBuffers[Int(i)].dealloc(mFFTInputBufferLen)
            drawBuffers[Int(i)] = nil
        }
        drawBuffers.dealloc(kNumDrawBuffers)
        
        mFFTInputBuffer.dealloc(mFFTInputBufferLen)
    }
    
    
    func copyAudioDataToDrawBuffer(inData: UnsafePointer<Float32>, inNumFrames: Int) {
        if inData == nil { return }
        
        for i in 0..<inNumFrames {
            if i + mDrawBufferIndex >= currentDrawBufferLength {
                cycleDrawBuffers()
                mDrawBufferIndex = -i
            }
            drawBuffers[0][i + mDrawBufferIndex] = inData[i]
        }
        mDrawBufferIndex += inNumFrames
    }
    
    
    func cycleDrawBuffers() {
        // Cycle the lines in our draw buffer so that they age and fade. The oldest line is discarded.
        for var drawBuffer_i = (kNumDrawBuffers - 2); drawBuffer_i>=0; drawBuffer_i-- {
            memmove(drawBuffers[drawBuffer_i + 1], drawBuffers[drawBuffer_i], size_t(currentDrawBufferLength))
        }
    }
    
    
    func CopyAudioDataToFFTInputBuffer(inData: UnsafePointer<Float32>, numFrames: Int) {
        var framesToCopy = min(numFrames, mFFTInputBufferLen - mFFTInputBufferFrameIndex)
        memcpy(mFFTInputBuffer.advancedBy(mFFTInputBufferFrameIndex), inData, size_t(framesToCopy * sizeof(Float32)))
        mFFTInputBufferFrameIndex += framesToCopy * sizeof(Float32)
        if mFFTInputBufferFrameIndex >= mFFTInputBufferLen {
            OSAtomicIncrement32(&mHasNewFFTData)
            OSAtomicDecrement32(&mNeedsNewFFTData)
        }
    }
    
    
    func GetFFTOutput(outFFTData: UnsafeMutablePointer<Float32>) {
        mFFTHelper.computeFFT(mFFTInputBuffer, outFFTData: outFFTData)
        mFFTInputBufferFrameIndex = 0
        OSAtomicDecrement32Barrier(&mHasNewFFTData)
        OSAtomicIncrement32Barrier(&mNeedsNewFFTData)
    }
}