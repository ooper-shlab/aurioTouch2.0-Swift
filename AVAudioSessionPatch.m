//
// AVAudioSessionPatch.m
//  https://forums.swift.org/t/using-methods-marked-unavailable-in-swift-4-2/14949/7
//

#import "AVAudioSessionPatch.h"

@implementation AVAudioSessionPatch

+ (BOOL)setSession:(AVAudioSession *)session category:(AVAudioSessionCategory)category withOptions:(AVAudioSessionCategoryOptions)options error:(__autoreleasing NSError **)outError {
    return [session setCategory:category withOptions:options error:outError];
}

@end
