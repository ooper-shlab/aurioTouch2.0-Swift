//
//  AudioBufferList+.swift
//  OOPUtils
//
//  Created by OOPer in cooperation with shlab.jp, on 2015/2/1.
//
//
/*
Copyright (c) 2015, OOPer(NAGATA, Atsuyuki)
All rights reserved.

Use of any parts(functions, classes or any other program language components)
of this file is permitted with no restrictions, unless you
redistribute or use this file in its entirety without modification.
In this case, providing any sort of warranties or not is the user's responsibility.

Redistribution and use in source and/or binary forms, without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import AVFoundation

func align(size: Int, to unit: Int) -> Int {
    assert(unit > 0)
    return ((size + unit - 1) / unit) * unit
}
func AudioBufferList_getAudioBufferPtr(ptrAudioBufferList: UnsafeMutablePointer<Void>, index: Int) -> UnsafeMutablePointer<AudioBuffer> {
    var ptr = UnsafeMutablePointer<CChar>(ptrAudioBufferList)
    ptr = ptr.advancedBy(AudioBufferList_size(index))
    return UnsafeMutablePointer(ptr)
}
func AudioBufferList_getAudioBuffer(ptrAudioBufferList: UnsafeMutablePointer<Void>, index: Int) -> AudioBuffer {
    return AudioBufferList_getAudioBufferPtr(ptrAudioBufferList, index).memory
}
func AudioBufferList_getDataPtr<T>(ptrAudioBufferList: UnsafeMutablePointer<Void>, index: Int) -> UnsafeMutablePointer<T> {
    return UnsafeMutablePointer(AudioBufferList_getAudioBuffer(ptrAudioBufferList, index).mData)
}
func AudioBufferList_getDataSize(ptrAudioBufferList: UnsafeMutablePointer<Void>, index: Int) -> Int {
    return Int(AudioBufferList_getAudioBuffer(ptrAudioBufferList, index).mDataByteSize)
}
func AudioBufferList_size(count: Int) -> Int {
    return align(strideof(UInt32), to: alignof(AudioBuffer)) + strideof(AudioBuffer) * count
}
func AudioBufferList_alloc(count: Int) -> UnsafeMutablePointer<AudioBufferList> {
    let size = AudioBufferList_size(count)
    let ptr = UnsafeMutablePointer<CChar>.alloc(size)
    return UnsafeMutablePointer(ptr)
}
func AudioBufferList_dealloc(inout ptrAudioBufferList: UnsafeMutablePointer<AudioBufferList>, count: Int) {
    var ptr = UnsafeMutablePointer<CChar>(ptrAudioBufferList)
    let size = AudioBufferList_size(count)
    ptr.dealloc(size)
    ptr = nil
}
