//
//  AudioController+RenderCallback.m
//  aurioTouch
//
//  Created by OOPer in cooperation with shlab.jp, on 2015/1/31.
//
//

#import "AudioController+RenderCallback.h"

OSStatus
AudioController_RenderCallback(
    void *                          inRefCon,
    AudioUnitRenderActionFlags *    ioActionFlags,
    const AudioTimeStamp *          inTimeStamp,
    UInt32                          inBusNumber,
    UInt32                          inNumberFrames,
    AudioBufferList *               ioData)
{
    AudioController_RenderBlock block = *(AudioController_RenderBlock *)inRefCon;
    return block(ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);
}

AURenderCallbackStruct createRenderCallback(const AudioController_RenderBlock *block) {
    AURenderCallbackStruct renderCallback;
    renderCallback.inputProc = AudioController_RenderCallback;
    renderCallback.inputProcRefCon = (void*)block;
    return renderCallback;
}
