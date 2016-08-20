//
//  CADebugMacros.swift
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

//=============================================================================
//	Includes
//=============================================================================

import CoreAudio

//=============================================================================
//	CADebugMacros
//=============================================================================

//	This is a macro that does a sizeof and casts the result to a UInt32. This is useful for all the
//	places where -wshorten64-32 catches assigning a sizeof expression to a UInt32.
//	For want of a better place to park this, we'll park it here.
func SizeOf32<T>(_ X: T) ->UInt32 {return UInt32(MemoryLayout<T>.stride)}
func SizeOf32<T>(_ X: T.Type) ->UInt32 {return UInt32(MemoryLayout<T>.stride)}


func DebugMsg(_ inFormat: String, args: CVarArg...) {}

//	Old-style numbered DebugMessage calls are implemented in terms of DebugMsg() now
func DebugMessageN2(_ msg: String, N1: CVarArg, N2: CVarArg) {DebugMsg(msg, args: N1, N2)}
