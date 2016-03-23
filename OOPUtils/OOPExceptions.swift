//
//  OOPExceptions.swift
//  OOPUtils
//
//  Created by OOPer in cooperation with shlab.jp, on 2015/1/31.
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

import Foundation

public class OOPThrowable: CustomStringConvertible, ErrorType {
    public var _domain: String = "OOPThrowable"
    public var _code: Int = 0
    
    private(set) var message: String
    var localizedMessage: String {return message}
    private(set) var cause: OOPThrowable?
    
    private(set) var file: String
    private(set) var function: String
    private(set) var line: Int
    
    init(message: String = "", cause: OOPThrowable? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line, column: Int = #column)
    {
        self.message = message
        self.cause = cause
        self.file = file
        self.function = function
        self.line = line
    }
    
    func initCause(cause: OOPThrowable) {
        if self.cause != nil {
            fatalError("cause already set")
        }
        self.cause = cause
    }

    public var description: String {
        return "\(message) in \(function) of \(file):\(line)"
    }
    //We don't have stack trace facility for now.
}
class OOPException: OOPThrowable {
    
}
