//
//  JKSMoviePlayerController.h
//  JKSMoviePlayer
//
//  Created by Johan Sørensen on 8/21/12.
//  Copyright (c) 2012 Johan Sørensen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>

typedef NS_ENUM(NSUInteger, JKSMoviePlayerScalingMode) {
    JKSMoviePlayerScalingResizeAspect,     // Preserve aspect ratio; fit within layer bounds.
    JKSMoviePlayerScalingResizeAspectFill, // Preserve aspect ratio; fill layer bounds.
    JKSMoviePlayerScalingResize,           // Stretch to fill layer bounds.
};

@interface JKSMoviePlayerController : NSObject
@property (copy, readonly) NSURL *contentURL;
@property (nonatomic, strong, readonly) AVPlayer *player;
@property (strong, readonly) NSView *view;
@property (nonatomic, assign) JKSMoviePlayerScalingMode scalingMode;
@property (nonatomic, readonly) Float64 duration;
@property (nonatomic, assign) Float64 currentTime;
@property (assign, readonly, getter=isPlayable) BOOL playable;
@property (assign) bool neverFadeOut;

- (instancetype)initWithContentURL:(NSURL *)fileURL;

- (void) setSmallControllerView;
- (void)play;
- (void)pause;
- (void)cancel;
@end
