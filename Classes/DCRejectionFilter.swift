//
//  DCRejectionFilter.swift
//  aurioTouch
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/29.
//
//
/*

 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 This class implements a DC Rejection Filter which is used to get rid of the DC component in an audio signal

 */


import AudioToolbox


class DCRejectionFilter {

    private var mY1: Float32 = 0.0
    private var mX1: Float32 = 0.0

    
    private final let kDefaultPoleDist: Float32 = 0.975

    
    func processInplace(_ ioData: UnsafeMutablePointer<Float32>, numFrames: UInt32) {
        for i in 0..<Int(numFrames) {
            let xCurr = ioData[i]
            ioData[i] = ioData[i] - mX1 + (kDefaultPoleDist * mY1)
            mX1 = xCurr
            mY1 = ioData[i]
        }
    }
}
