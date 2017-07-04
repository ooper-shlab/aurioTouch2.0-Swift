//
//  CAXException.swift
//  aurioTouch
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/31.
//
//
/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 Part of CoreAudio Utility Classes
*/

import Foundation


class CAX4CCString {
    init(error: OSStatus) {
        // see if it appears to be a 4-char-code
        var str: [CChar] = Array(repeating: 0, count: 16)
        if
            let c1 = CChar(exactly: (error >> 24) & 0xFF),
            let c2 = CChar(exactly: (error >> 16) & 0xFF),
            let c3 = CChar(exactly: (error >> 8) & 0xFF),
            let c4 = CChar(exactly: error & 0xFF),
            isprint(Int32(c1)) != 0 && isprint(Int32(c2)) != 0 && isprint(Int32(c3)) != 0 && isprint(Int32(c4)) != 0
        {
            str[0] = CChar("\'")
            str[1] = c1
            str[2] = c2
            str[3] = c3
            str[4] = c4
            str[5] = CChar("\'")
            str[6] = 0
            mStr = String(cString: str)
        } else if error > -200000 && error < 200000 {
            // no, format it as an integer
            mStr = String(Int32(error))
        } else {
            mStr = "0x" + String(UInt32(bitPattern: error), radix: 16)
        }
    }
    func get() -> String {
        return mStr
    }
    private(set) var mStr: String
}

// An extended exception class that includes the name of the failed operation
class CAXException: OOPException {
    init(operation: String?, err: OSStatus) {
        mError = err
        if operation == nil {
            mOperation = ""
        } else {
            
            mOperation = operation!
        }
    }
    
    func formatError() -> String {
        return type(of: self).formatError(mError)
    }
    
    var mOperation: String
    private(set) var mError: OSStatus
    
    // -------------------------------------------------
    
    typealias WarningHandler = (String, OSStatus) -> Void
    
    
    class func formatError(_ error: OSStatus) -> String {
        return CAX4CCString(error: error).get()
    }
    
    class func warning(_ s: String, error: OSStatus) {
        sWarningHandler?(s, error)
    }
    
    class func setWarningHandler(_ f: @escaping WarningHandler) { sWarningHandler = f }
    private static var sWarningHandler: WarningHandler? = nil
    
    override var description: String {
        return "Error \(formatError()) in operation: \(mOperation)"
    }
}

func XExceptionIfError(_ error: NSError?, _ operation: String) throws {
    if error != nil && error!.code != 0 {
        throw CAXException(operation: operation, err: OSStatus(error!.code))
    }
}
func XFailIfError(_ error: NSError?, _ operation: String) {
    if error != nil && error!.code != 0 {
        XFailIfError(OSStatus(error!.code), operation)
    }
}
func XExceptionIfError(_ error: OSStatus, _ operation: String) throws {
    if error != 0 {
        throw CAXException(operation: operation, err: error)
    }
}
func XFailIfError(_ error: OSStatus, _ operation: String) {
    if error != 0 {
        fatalError(CAXException(operation: operation, err: error).description)
    }
}
