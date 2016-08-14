/*
 
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This class implements a DC Rejection Filter which is used to get rid of the DC component in an audio signal
 
 */

#include "DCRejectionFilter.h"


const Float32 kDefaultPoleDist = 0.975f;


DCRejectionFilter::DCRejectionFilter()
{
	mY1 = mX1 = 0;
}


DCRejectionFilter::~DCRejectionFilter()
{
}


void DCRejectionFilter::ProcessInplace(Float32* ioData, UInt32 numFrames)
{
	for (UInt32 i=0; i < numFrames; i++)
	{
        Float32 xCurr = ioData[i];
		ioData[i] = ioData[i] - mX1 + (kDefaultPoleDist * mY1);
        mX1 = xCurr;
        mY1 = ioData[i];
	}
}
