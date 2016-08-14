/*
 
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This class implements a DC Rejection Filter which is used to get rid of the DC component in an audio signal
 
 */

#ifndef __aurioTouch3__DCRejectionFilter__
#define __aurioTouch3__DCRejectionFilter__


#include <AudioToolbox/AudioToolbox.h>


class DCRejectionFilter
{
public:
	DCRejectionFilter();
    ~DCRejectionFilter();
    
	void ProcessInplace(Float32* ioData, UInt32 numFrames);
    
private:
	Float32 mY1;
	Float32 mX1;
};

#endif /* defined(__aurioTouch3__DCRejectionFilter__) */
