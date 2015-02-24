//
//  CAStreamBasicDescription.swift
//  aurioTouch
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/31.
//
//
/*
     File: CAStreamBasicDescription.h
     File: CAStreamBasicDescription.cpp
 Abstract: Part of CoreAudio Utility Classes
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

import Foundation
import CoreAudio


//=============================================================================
//	CAStreamBasicDescription
//
//	This is a wrapper class for the AudioStreamBasicDescription struct.
//	It adds a number of convenience routines, but otherwise adds nothing
//	to the footprint of the original struct.
//=============================================================================
typealias CAStreamBasicDescription = AudioStreamBasicDescription
extension AudioStreamBasicDescription {
    
    enum CommonPCMFormat: Int {
        case Other = 0
        case Float32 = 1
        case Int16 = 2
        case Fixed824 = 3
    }
    
    //	Construction/Destruction
    //You have all-zero default initializer for imported structs in Swift 1.2 .
//    init() {self = empty_struct()}
    
    init(desc: AudioStreamBasicDescription) {
        self = desc
    }
    
    init?(sampleRate inSampleRate: Double, numChannels inNumChannels: UInt32, pcmf: CommonPCMFormat, isInterleaved inIsInterleaved: Bool) {
        self.init()
        var wordsize: UInt32
        
        mSampleRate = inSampleRate
        mFormatID = AudioFormatID(kAudioFormatLinearPCM)
        mFormatFlags = AudioFormatFlags(kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked)
        mFramesPerPacket = 1
        mChannelsPerFrame = inNumChannels
        mBytesPerFrame = 0
        mBytesPerPacket = 0
        mReserved = 0
        
        switch pcmf {
        case .Float32:
            wordsize = 4
            mFormatFlags |= AudioFormatFlags(kAudioFormatFlagIsFloat)
        case .Int16:
            wordsize = 2
            mFormatFlags |= AudioFormatFlags(kAudioFormatFlagIsSignedInteger)
        case .Fixed824:
            wordsize = 4
            mFormatFlags |= AudioFormatFlags(kAudioFormatFlagIsSignedInteger | (24 << kLinearPCMFormatFlagsSampleFractionShift))
        default:
            return nil
        }
        mBitsPerChannel = wordsize * 8
        if inIsInterleaved {
            mBytesPerFrame = wordsize * inNumChannels
            mBytesPerPacket = mBytesPerFrame
        } else {
            mFormatFlags |= AudioFormatFlags(kAudioFormatFlagIsNonInterleaved)
            mBytesPerFrame = wordsize
            mBytesPerPacket = mBytesPerFrame
        }
    }
}