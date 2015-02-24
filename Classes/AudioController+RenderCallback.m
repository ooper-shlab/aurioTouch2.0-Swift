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
AudioController_RenderCallback(
    void *                          inRefCon,
    AudioUnitRenderActionFlags *    ioActionFlags,
    const AudioTimeStamp *          inTimeStamp,
    UInt32                          inBusNumber,
    UInt32                          inNumberFrames,
    AudioBufferList *               ioData)
{
    AudioController *controller = (AudioController *)inRefCon;
    OSStatus result = controller.performRenderCallback(ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);
    return result;
}

AURenderCallbackStruct createRenderCallback(const AudioController *controller) {
    AURenderCallbackStruct renderCallback;
    renderCallback.inputProc = AudioController_RenderCallback;
    renderCallback.inputProcRefCon = (void*)controller;
    return renderCallback;
}
