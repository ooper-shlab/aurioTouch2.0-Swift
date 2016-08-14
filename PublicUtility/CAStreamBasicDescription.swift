//
//  CAStreamBasicDescription.swift
//  aurioTouch
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/31.
//
//
/*
Copyright (C) 2016 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
Part of Core Audio Public Utility Classes
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
        case other = 0
        case float32 = 1
        case int16 = 2
        case fixed824 = 3
        case float64 = 4
        case int32 = 5
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
        case .float32:
            wordsize = 4
            mFormatFlags |= AudioFormatFlags(kAudioFormatFlagIsFloat)
        case .float64:
            wordsize = 8
            mFormatFlags |= AudioFormatFlags(kAudioFormatFlagIsFloat)
            break;
        case .int16:
            wordsize = 2
            mFormatFlags |= AudioFormatFlags(kAudioFormatFlagIsSignedInteger)
        case .int32:
            wordsize = 4
            mFormatFlags |= AudioFormatFlags(kAudioFormatFlagIsSignedInteger)
            break;
        case .fixed824:
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
