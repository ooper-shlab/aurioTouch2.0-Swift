//
//  AudioController+RenderCallback.h
//  aurioTouch
//
//  Created by OOPer in cooperation with shlab.jp, on 2015/1/31.
//
//

#ifndef aurioTouch_AudioController_RenderCallback_h
#define aurioTouch_AudioController_RenderCallback_h

#import <AudioUnit/AudioUnitProperties.h>

@class AudioController;

typedef OSStatus
(^AudioController_RenderBlock)(
    AudioUnitRenderActionFlags *    ioActionFlags,
    const AudioTimeStamp *          inTimeStamp,
    UInt32                          inBusNumber,
    UInt32                          inNumberFrames,
    AudioBufferList *               ioData);

AURenderCallbackStruct createRenderCallback(const AudioController *controller);

#endif
