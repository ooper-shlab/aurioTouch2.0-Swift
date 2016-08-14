/*
 
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView subclass
 
 */

// Framework includes
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

// Local includes
#import "AudioController.h"

@interface EAGLView : UIView

@property (assign)  BOOL applicationResignedActive;

- (void)startAnimation;
- (void)stopAnimation;

@end
