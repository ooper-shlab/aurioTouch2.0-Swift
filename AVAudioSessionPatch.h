//
// AVAudioSessionPatch.h
//  https://forums.swift.org/t/using-methods-marked-unavailable-in-swift-4-2/14949/7
//

@import AVFoundation;

NS_ASSUME_NONNULL_BEGIN

@interface AVAudioSessionPatch : NSObject

+ (BOOL)setSession:(AVAudioSession *)session category:(AVAudioSessionCategory)category withOptions:(AVAudioSessionCategoryOptions)options error:(__autoreleasing NSError **)outError;

@end

NS_ASSUME_NONNULL_END
