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

@protocol AURenderCallbackDelegate
- (OSStatus)performRender:(AudioUnitRenderActionFlags *)ioActionFlags
              inTimeStamp:(const AudioTimeStamp *)inTimeStamp
              inBufNumber:(UInt32)inBufNumber
           inNumberFrames:(UInt32)inNumberFrames
                   ioData:(AudioBufferList *)ioData;
@end

AURenderCallbackStruct createRenderCallback(const id<AURenderCallbackDelegate> delegate);

#endif
