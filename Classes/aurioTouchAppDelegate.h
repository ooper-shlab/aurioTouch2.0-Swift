/*
 
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 App delegate
 
 */

@class EAGLView;

@interface aurioTouchAppDelegate : NSObject <UIApplicationDelegate> {
	IBOutlet UIWindow       *window;
	IBOutlet EAGLView       *view;
}

@property (nonatomic, retain)	UIWindow        *window;
@property (nonatomic, retain)	EAGLView        *view;

@end
