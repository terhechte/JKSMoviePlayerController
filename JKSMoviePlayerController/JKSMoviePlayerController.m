//
//  JKSMoviePlayerController.m
//  JKSMoviePlayer
//
//  Created by Johan Sørensen on 8/21/12.
//  Copyright (c) 2012 Johan Sørensen. All rights reserved.
//

#import "JKSMoviePlayerController.h"
#import <QuartzCore/QuartzCore.h>
#import "JKSMoviePlayerControllerView.h"

/* Partially based on the AVSimplePlayer sample from Apple */

static void *JKSMoviePlayerControllerRateContext = &JKSMoviePlayerControllerRateContext;
static void *JKSMoviePlayerControllerItemStatusContext = &JKSMoviePlayerControllerItemStatusContext;
static void *JKSMoviePlayerPlayerLayerReadyForDisplay = &JKSMoviePlayerPlayerLayerReadyForDisplay;

@interface JKSMoviePlayerController () {
    AVURLAsset *_asset;
}
- (void)loadContentForURL:(NSURL*)fileURL;

@property (strong, readwrite) NSView *view;
@property (retain) id timeObserverToken;
@property (strong) AVPlayer *player;
@property (strong) AVPlayerLayer *playerLayer;
@property (strong) JKSMoviePlayerControllerView *controllerView;
@property (strong) NSTimer *timer;
@property (assign, readwrite, getter=isPlayable) BOOL playable;
@end

@implementation JKSMoviePlayerController
{
    NSProgressIndicator *_spinner;
    NSTimer *_downloadStateTimer;
}

- (instancetype)initWithContentURL:(NSURL *)fileURL
{
    if ((self = [super init])) {
        _scalingMode = JKSMoviePlayerScalingResizeAspect;
        _playable = NO;

        _view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 800, 450)];
        [_view setPostsBoundsChangedNotifications:YES];
        [_view setPostsFrameChangedNotifications:YES];
        
        [[NSNotificationCenter defaultCenter]
         addObserver:self selector:@selector(viewDidResize:)
         name:NSViewBoundsDidChangeNotification
         object:_view];
        
        [[NSNotificationCenter defaultCenter]
         addObserver:self selector:@selector(viewDidResize:)
         name:NSViewFrameDidChangeNotification
         object:_view];
        
        [_view setWantsLayer:YES];
        _spinner = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
        [_spinner setStyle:NSProgressIndicatorSpinningStyle];
        [_spinner startAnimation:self];
        [_view addSubview:_spinner];

        [_view layer].backgroundColor = [[NSColor blackColor] CGColor];
        NSTrackingArea *tracker = [[NSTrackingArea alloc] initWithRect:[_view bounds]
                                                               options:(NSTrackingActiveInKeyWindow |
                                                                        NSTrackingMouseEnteredAndExited |
                                                                        NSTrackingMouseMoved |
                                                                        NSTrackingInVisibleRect)
                                                                 owner:self
                                                              userInfo:nil];
        [_view addTrackingArea:tracker];

        _player = [[AVPlayer alloc] init];
        _player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
        [self addObserver:self
               forKeyPath:@"player.rate"
                  options:NSKeyValueObservingOptionNew
                  context:JKSMoviePlayerControllerRateContext];
        [self addObserver:self
               forKeyPath:@"player.currentItem.status"
                  options:NSKeyValueObservingOptionNew
                  context:JKSMoviePlayerControllerItemStatusContext];

        [self loadContentForURL:fileURL];
        
        _controllerView = [[JKSMoviePlayerControllerView alloc] initWithFrame:NSMakeRect(0, 0, 440, 40)];
        [_view addSubview:_controllerView];
        [_controllerView setAlphaValue:0];
        
        [_controllerView.playPauseButton setTarget:self];
        [_controllerView.playPauseButton setAction:@selector(playPauseToggle:)];
        [_controllerView.playPauseButton setEnabled:NO];

        [_controllerView.timeSlider setTarget:self];
        [_controllerView.timeSlider setAction:@selector(scrubberChanged:)];
        [_controllerView.timeSlider setEnabled:NO];
        
        [self layoutInterface];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeObserver:self forKeyPath:@"player.rate"];
    [self removeObserver:self forKeyPath:@"player.currentItem.status"];
    [_player removeTimeObserver:self.timeObserverToken];
    if (_playerLayer)
		[self removeObserver:self forKeyPath:@"playerLayer.readyForDisplay"];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == JKSMoviePlayerControllerItemStatusContext) {
		AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
		BOOL enable = NO;
		switch (status) {
			case AVPlayerItemStatusUnknown:
				break;
			case AVPlayerItemStatusReadyToPlay:
				enable = YES;
				break;
			case AVPlayerItemStatusFailed:
				[self stopLoadingAnimationAndHandleError:[[self.player currentItem] error]];
				break;
		}
		
        [self fadeInControllerView];
        [_controllerView.playPauseButton setEnabled:enable];
        [_controllerView.timeSlider setEnabled:enable];
        if (enable) {
            [_controllerView.timeSlider setMaxValue:[self duration]];
            [self updateTimeLabel];
            
        }
	} else if (context == JKSMoviePlayerControllerRateContext) {
		float rate = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		if (rate != 1.0f) {
            [_controllerView setPlaying:NO];
		} else {
            [_controllerView setPlaying:YES];
		}
	} else if (context == JKSMoviePlayerPlayerLayerReadyForDisplay) {
		if ([[change objectForKey:NSKeyValueChangeNewKey] boolValue] == YES) {
			// The AVPlayerLayer is ready for display. Hide the loading spinner and show it.
			[self stopLoadingAnimationAndHandleError:nil];
			[self.playerLayer setHidden:NO];
		}
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void) viewDidResize:(NSNotification*)notification {
    [self layoutInterface];
}

- (void) setSmallControllerView {
    NSRect f = [_view frame];
    NSRect c = [_controllerView frame];
    [_controllerView setFrame:NSMakeRect(20, 20, (NSWidth(f)/2)-40, NSHeight(c))];
}

- (void) layoutInterface {
    NSRect f = [_view frame];
    NSRect s = [_spinner frame];
    [_spinner setFrame:NSMakeRect(NSWidth(f)/2 - NSWidth(s)/2, NSHeight(f)/2 - NSHeight(s)/2,
                                  NSWidth(s), NSHeight(s))];
    
    NSRect c = [_controllerView frame];
    [_controllerView setFrame:NSMakeRect(20, 20, NSWidth(f)-40, NSHeight(c))];
}

- (Float64)duration
{
	AVPlayerItem *playerItem = [self.player currentItem];

	if ([playerItem status] == AVPlayerItemStatusReadyToPlay) {
		return CMTimeGetSeconds([[playerItem asset] duration]);
	} else {
		return 0.f;
    }
}


- (Float64)currentTime
{
	return CMTimeGetSeconds([self.player currentTime]);
}


- (void)setCurrentTime:(Float64)time
{
    [self.player seekToTime:CMTimeMakeWithSeconds(time, 1) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}


- (void)setScalingMode:(JKSMoviePlayerScalingMode)scalingMode
{
    _scalingMode = scalingMode;
    [self updateScalingMode];
}


- (void)play
{
    [self.player play];
}


- (void)pause
{
    [self.player pause];
}


#pragma mark - Event handling

- (void)mouseEntered:(NSEvent *)event
{
    [[_controllerView animator] setAlphaValue:1];
}


- (void)mouseExited:(NSEvent *)event
{
    [self fadeOutContorllerViewDelayed];
}


- (void)mouseMoved:(NSEvent *)event
{
    [self fadeInControllerView];
    [self fadeOutContorllerViewDelayed];
}


#pragma mark - Control actions

- (void)playPauseToggle:(id)sender
{
	if ([self.player rate] != 1.f) {
		if (self.currentTime >= self.duration) {
            self.currentTime = 0.0f;
        }
		[self.player play];
	} else {
		[self.player pause];
	}
}


- (void)scrubberChanged:(NSSlider *)sender
{
    if ([self.player rate] >= 1.0f) {
        [self.player pause];
    }
    [self.player seekToTime:CMTimeMakeWithSeconds([sender doubleValue], NSEC_PER_SEC)];
}


#pragma mark - Private methods

- (void)fadeInControllerView
{
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOutControllerView) object:nil];
    [[_controllerView animator] setAlphaValue:1];
    [self fadeOutContorllerViewDelayed];
}


- (void)fadeOutContorllerViewDelayed
{
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOutControllerView) object:nil];
    [self performSelector:@selector(fadeOutControllerView) withObject:nil afterDelay:1.6];
}


- (void)fadeOutControllerView
{
    if (self.neverFadeOut)return;
    [[_controllerView animator] setAlphaValue:0];
}


- (void)setUpPlaybackOfAsset:(AVAsset *)asset withKeys:(NSArray *)keys
{
	// This method is called when the AVAsset for our URL has completing the loading of the values of the specified array of keys.
	// We set up playback of the asset here.
	
	// First test whether the values of each of the keys we need have been successfully loaded.
	for (NSString *key in keys) {
		NSError *error = nil;
		if ([asset statusOfValueForKey:key error:&error] == AVKeyValueStatusFailed) {
			[self stopLoadingAnimationAndHandleError:error];
			return;
		}
	}
	
	if (![asset isPlayable] || [asset hasProtectedContent]) {
		// We can't play this asset. Show the "Unplayable Asset" label.
		[self stopLoadingAnimationAndHandleError:nil];
        self.playable = NO;
        NSLog(@"can't play this. playable=%d protected=%d", [asset isPlayable], [asset hasProtectedContent]);
		return;
	}

    self.playable = YES;

	// We can play this asset.
	// Set up an AVPlayerLayer according to whether the asset contains video.
	if ([[asset tracksWithMediaType:AVMediaTypeVideo] count] != 0) {
        // if we already have a playerLayer, remove it
        if (_playerLayer)
        {
            [_playerLayer removeFromSuperlayer];
            _playerLayer = nil;
        }
		// Create an AVPlayerLayer and add it to the player view if there is video, but hide it until it's ready for display
		_playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
		_playerLayer.frame = [[_view layer] bounds];
        _playerLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
		_playerLayer.hidden = YES;
		//[[_view layer] addSublayer:_playerLayer];
        [[_view layer] insertSublayer:_playerLayer below:[_controllerView layer]];
		[self addObserver:self
               forKeyPath:@"playerLayer.readyForDisplay"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:JKSMoviePlayerPlayerLayerReadyForDisplay];
	} else {
		// This asset has no video tracks. Show the "No Video" label.
		[self stopLoadingAnimationAndHandleError:nil];
	}
	
	// Create a new AVPlayerItem and make it our player's current item.
	AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
	[_player replaceCurrentItemWithPlayerItem:playerItem];
    __weak JKSMoviePlayerController *weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:playerItem
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                      [[weakSelf.controllerView animator] setAlphaValue:1];
                                                  }];
	_timeObserverToken = [_player addPeriodicTimeObserverForInterval:CMTimeMake(1, 10)
                                                               queue:dispatch_get_main_queue()
                                                          usingBlock:^(CMTime time) {
                                                              [weakSelf.controllerView.timeSlider setDoubleValue:CMTimeGetSeconds(time)];
                                                              [weakSelf updateTimeLabel];
                                                          }];
    [self updateScalingMode];
}


- (void)updateTimeLabel
{
    if (CMTIME_IS_INVALID([self.player currentTime])) {
        [self.controllerView.timeLabel setStringValue:@"--:--"];
    } else {
        Float64 seconds = CMTimeGetSeconds([self.player currentTime]);
        NSUInteger minutes = seconds / 60;
        NSUInteger secondsLeftOver = seconds - (minutes * 60);
        NSString *timeString = [NSString stringWithFormat:@"%02ld:%02ld", minutes, secondsLeftOver];
        [self.controllerView.timeLabel setStringValue:timeString];
    }
}



- (void)stopLoadingAnimationAndHandleError:(NSError *)error
{
	[_spinner stopAnimation:self];
	[_spinner setHidden:YES];
	if (error) {
//        NSLog(@"%@: %@", NSStringFromSelector(_cmd), error);
        // TODO: Notify delegate
	}
}


- (void)updateScalingMode
{
    switch (_scalingMode) {
        case JKSMoviePlayerScalingResizeAspect:
            _playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
            break;
        case JKSMoviePlayerScalingResizeAspectFill:
            _playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
            break;
        case JKSMoviePlayerScalingResize:
            _playerLayer.videoGravity = AVLayerVideoGravityResize;
            break;
        default:
            break;
    }
}

- (void)cancel {
    if (_asset)[_asset cancelLoading];
}

- (void)loadContentForURL:(NSURL*)fileURL
{
    
    // Create an asset with our URL, asychronously load its tracks, its duration, and whether it's playable or protected.
    // When that loading is complete, configure a player to play the asset.
    _contentURL = [fileURL copy];
    _asset = [AVAsset assetWithURL:_contentURL];
    NSArray *assetKeysToLoadAndTest = @[@"playable", @"hasProtectedContent", @"tracks", @"duration"];
    [_asset loadValuesAsynchronouslyForKeys:assetKeysToLoadAndTest completionHandler:^(void) {
        // The asset invokes its completion handler on an arbitrary queue when loading is complete.
        // Because we want to access our AVPlayer in our ensuing set-up, we must dispatch our handler to the main queue.
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self setUpPlaybackOfAsset:_asset withKeys:assetKeysToLoadAndTest];
            _asset = nil;
        });
        
    }];
    
    // start measuring the download state
    if (_downloadStateTimer) {
        [_downloadStateTimer invalidate];
        _downloadStateTimer = nil;
    }
    _downloadStateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                           target:self
                                                         selector:@selector(updateDownloadDuration)
                                                         userInfo:nil
                                                          repeats:YES];
}

- (void) updateDownloadDuration {
    NSTimeInterval currentDuration = [self availableDuration];
    NSTimeInterval totalDuration = CMTimeGetSeconds(self.player.currentItem.asset.duration);
    
    
    if (isnan(currentDuration) || isnan(totalDuration)) {
        [self.controllerView setDownloadPercentage:0];
        return;
    }

    if (currentDuration >= totalDuration) {
        [_downloadStateTimer invalidate];
        _downloadStateTimer = nil;
    }
    
    // update the display
    [self.controllerView setDownloadPercentage:currentDuration/totalDuration];
}

// http://stackoverflow.com/questions/7691854/avplayer-streaming-progress
- (NSTimeInterval) availableDuration;
{
    NSArray *loadedTimeRanges = [[self.player currentItem] loadedTimeRanges];
    CMTimeRange timeRange = [[loadedTimeRanges objectAtIndex:0] CMTimeRangeValue];
    Float64 startSeconds = CMTimeGetSeconds(timeRange.start);
    Float64 durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds + durationSeconds;
    return result;
}


@end
