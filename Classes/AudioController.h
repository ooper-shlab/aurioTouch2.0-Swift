/*
 
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This class demonstrates the audio APIs used to capture audio data from the microphone and play it out to the speaker. It also demonstrates how to play system sounds
 
 */

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#import "BufferManager.h"
#import "DCRejectionFilter.h"


@interface AudioController : NSObject {
    
    AudioUnit               _rioUnit;
    BufferManager*          _bufferManager;
    DCRejectionFilter*      _dcRejectionFilter;
    AVAudioPlayer*          _audioPlayer;   // for button pressed sound
    BOOL                    _audioChainIsBeingReconstructed;
}

@property (nonatomic, assign) BOOL muteAudio;
@property (nonatomic, assign, readonly) BOOL audioChainIsBeingReconstructed;

- (BufferManager*) getBufferManagerInstance;
- (OSStatus)    startIOUnit;
- (OSStatus)    stopIOUnit;
- (void)        playButtonPressedSound;
- (double)      sessionSampleRate;

@end
