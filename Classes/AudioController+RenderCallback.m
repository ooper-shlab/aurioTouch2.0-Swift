//
//  AudioController+RenderCallback.m
//  aurioTouch
//
//  Created by OOPer in cooperation with shlab.jp, on 2015/1/31.
//
//

#import "AudioController+RenderCallback.h"
#import "aurioTouch-Swift.h"

OSStatus
AudioController_RenderCallback(void *                          inRefCon,
                               AudioUnitRenderActionFlags *    ioActionFlags,
                               const AudioTimeStamp *          inTimeStamp,
                               UInt32                          inBufNumber,
                               UInt32                          inNumberFrames,
                               AudioBufferList *               ioData)
{
    id<AURenderCallbackDelegate> delegate = (id<AURenderCallbackDelegate>)inRefCon;
    OSStatus result = [delegate performRender: ioActionFlags
                                  inTimeStamp: inTimeStamp
                                  inBufNumber: inBufNumber
                               inNumberFrames: inNumberFrames
                                       ioData: ioData];
    return result;
}

AURenderCallbackStruct createRenderCallback(const id<AURenderCallbackDelegate> delegate) {
    AURenderCallbackStruct renderCallback;
    renderCallback.inputProc = AudioController_RenderCallback;
    renderCallback.inputProcRefCon = (void*)delegate;
    return renderCallback;
}
