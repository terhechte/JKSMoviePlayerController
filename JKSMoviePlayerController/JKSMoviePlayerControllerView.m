//
//  JKSMoviePlayerControllerView.m
//  JKSMoviePlayer
//
//  Created by Johan Sørensen on 8/22/12.
//  Copyright (c) 2012 Johan Sørensen. All rights reserved.
//

#import "JKSMoviePlayerControllerView.h"

#ifndef NSCOLOR
#define NSCOLOR(r, g, b, a) [NSColor colorWithCalibratedRed:r/255.0f green:g/255.0f blue:b/255.0f alpha:a]
#endif


@interface NSImage (PreMountainLionAddition)
@end

@implementation NSImage (PreMountainLionAddition)
+ (id)IG_imageWithSize:(NSSize)size flipped:(BOOL)drawingHandlerShouldBeCalledWithFlippedContext drawingHandler:(BOOL (^)(NSRect dstRect))drawingHandler
{
    if ([NSImage respondsToSelector:@selector(imageWithSize:flipped:drawingHandler:)])
    {
        return [NSImage imageWithSize:size flipped:drawingHandlerShouldBeCalledWithFlippedContext drawingHandler:drawingHandler];
    } else {
        // our custom implementation
        NSImage *img = [[NSImage alloc] initWithSize:size];
        [img setFlipped:drawingHandlerShouldBeCalledWithFlippedContext];
        [img lockFocus];
        drawingHandler(NSMakeRect(0, 0, size.width, size.height));
        [img unlockFocus];
        return img;
    }
}
@end

@interface JKSMoviePlayerSliderCell : NSSliderCell
@end

@implementation JKSMoviePlayerSliderCell

- (NSRect)knobRectFlipped:(BOOL)flipped
{
    NSRect knobRect = [super knobRectFlipped:flipped];
    knobRect.origin.x += 6;
    knobRect.origin.y += 7.5;
    knobRect.size.height = 8;
    knobRect.size.width = 8;
    return knobRect;
}


- (void)drawKnob:(NSRect)knobRect
{
    NSBezierPath *outerPath = [NSBezierPath bezierPathWithOvalInRect:knobRect];
    NSGradient *outerGradient = [[NSGradient alloc] initWithColors:@[NSCOLOR(193, 193, 193, 1), NSCOLOR(120, 120, 120, 1)]];
    [outerGradient drawInBezierPath:outerPath angle:90];
    NSBezierPath *innerPath = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(knobRect, 2, 2)];
    NSGradient *innerGradient = [[NSGradient alloc] initWithColors:@[NSCOLOR(154, 154, 154, 1), NSCOLOR(127, 127, 127, 1)]];
    [innerGradient drawInBezierPath:innerPath angle:90];
}


- (void)drawBarInside:(NSRect)aRect flipped:(BOOL)flipped
{
    NSRect sliderRect = aRect;
    sliderRect.origin.y += (NSMaxY(sliderRect) / 2) - 4;
    sliderRect.origin.x += 2;
    sliderRect.size.width -= 4;
    sliderRect.size.height = 11;

    NSBezierPath *barPath = [NSBezierPath bezierPathWithRoundedRect:sliderRect xRadius:4 yRadius:4];
    NSGradient *borderGradient = [[NSGradient alloc] initWithColors:@[NSCOLOR(3, 3, 3, 1), NSCOLOR(23, 23, 23, 1)]];
    [borderGradient drawInBezierPath:barPath angle:90];
    NSBezierPath *innerPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(sliderRect, 1, 1) xRadius:4 yRadius:4];
    [NSCOLOR(13, 13, 13, 1) setFill];
    [innerPath fill];
}


@end


@interface JKSMoviePlayerSlider : NSSlider
@end

@implementation JKSMoviePlayerSlider
+ (Class)cellClass { return [JKSMoviePlayerSliderCell class]; }
@end


@implementation JKSMoviePlayerControllerView

- (id)initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        [self setWantsLayer:YES];

        NSRect playPauseRect = NSMakeRect(0, 0, 18, 18);
        _playPauseButton = [self createButtonWithFrame:playPauseRect image:[self playImageWithSize:playPauseRect.size]];
        [self addSubview:_playPauseButton];

        _timeSlider = [[JKSMoviePlayerSlider alloc] initWithFrame:NSMakeRect(0, 0, 235, 20)];
        [self addSubview:_timeSlider];

        _timeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 40, 16)];
        [_timeLabel setBezeled:NO];
        [_timeLabel setDrawsBackground:NO];
        [_timeLabel setEditable:NO];
        [_timeLabel setSelectable:NO];
        [_timeLabel setTextColor:[NSColor whiteColor]];
        [_timeLabel setStringValue:@"--:--"];
        [self addSubview:_timeLabel];
        
    }

    return self;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize {
    [self updateLayout];
}

- (void) updateLayout {
    NSRect f = [self frame];
    NSRect p = [_playPauseButton frame];
    p.origin.x = 10;
    p.origin.y = NSHeight(f) / 2 - NSHeight(p)/2;
    p.size.width = 18;
    
    NSRect t = [_timeSlider frame];
    NSRect l = [_timeLabel frame];
    
    t.size.width = NSWidth(f) - (NSWidth(p) + p.origin.x + 10 + NSWidth(l) + 10);
    t.origin.x = NSWidth(p) + p.origin.x + 10;
    t.origin.y = NSHeight(f) / 2 - NSHeight(t)/2;
    
    l.origin.x = NSWidth(f) - (NSWidth(l) + 10);
    l.origin.y = NSHeight(f) / 2 - NSHeight(l)/2;
    
    [_playPauseButton setFrame:p];
    [_timeSlider setFrame:t];
    [_timeLabel setFrame:l];
}


- (void)drawRect:(NSRect)dirtyRect
{
    NSRect innerRect = NSInsetRect([self bounds], 0, 2);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:innerRect xRadius:5 yRadius:5];
    [[NSColor colorWithDeviceWhite:0.2 alpha:0.85] set];
    [path fill];
}


- (void)setPlaying:(BOOL)flag
{
    if (flag) {
        [self.playPauseButton setToolTip:@"Pause"];
        [self.playPauseButton setImage:[self pauseImageWithSize:[self.playPauseButton frame].size]];
    } else {
        [self.playPauseButton setToolTip:@"Play"];
        [self.playPauseButton setImage:[self playImageWithSize:[self.playPauseButton frame].size]];
    }
}


#pragma mark - Private methods

- (NSButton *)createButtonWithFrame:(NSRect)frame image:(NSImage *)image
{
    NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 25, 18)];
    [button setButtonType:NSMomentaryChangeButton];
    [button setBordered:NO];
    [button setImage:image];
    return button;
}


- (NSImage *)rewindImageWithSize:(NSSize)size
{
    NSImage *image = [NSImage IG_imageWithSize:size flipped:YES drawingHandler:^BOOL(NSRect dstRect) {
        NSBezierPath *path = [[NSBezierPath alloc] init];
        [path moveToPoint:NSMakePoint(NSMinX(dstRect), NSMidY(dstRect))];
        [path lineToPoint:NSMakePoint(NSMidX(dstRect), NSMinY(dstRect))];
        [path lineToPoint:NSMakePoint(NSMidX(dstRect), NSMidY(dstRect))];
        [path lineToPoint:NSMakePoint(NSMaxX(dstRect), NSMinY(dstRect))]; // tri2
        [path lineToPoint:NSMakePoint(NSMaxX(dstRect), NSMaxY(dstRect))];
        [path lineToPoint:NSMakePoint(NSMidX(dstRect), NSMidY(dstRect))];
        [path lineToPoint:NSMakePoint(NSMidX(dstRect), NSMaxY(dstRect))]; // tri1 again
        [path lineToPoint:NSMakePoint(NSMinX(dstRect), NSMidY(dstRect))];
        [path closePath];
        [[NSColor whiteColor] setFill];
        [path fill];
        return YES;
    }];
    [image setTemplate:YES];
    return image;
}


- (NSImage *)playImageWithSize:(NSSize)size
{
    return [NSImage IG_imageWithSize:size flipped:YES drawingHandler:^BOOL(NSRect dstRect) {
        NSBezierPath *path = [[NSBezierPath alloc] init];
        [path moveToPoint:NSZeroPoint];
        [path lineToPoint:NSMakePoint(NSMaxX(dstRect), NSMidY(dstRect))];
        [path lineToPoint:NSMakePoint(NSMinX(dstRect), NSMaxY(dstRect))];
        [path closePath];
        [[NSColor whiteColor] setFill];
        [path fill];
        return YES;
    }];
}


- (NSImage *)pauseImageWithSize:(NSSize)size
{
    NSImage *image = [NSImage IG_imageWithSize:size flipped:YES drawingHandler:^BOOL(NSRect dstRect) {
        [[NSColor whiteColor] setFill];
        const CGFloat spacing = 2.0f;
        NSRectFill(NSMakeRect(NSMinX(dstRect), NSMinY(dstRect), (NSWidth(dstRect)/2)-spacing, NSHeight(dstRect)));
        NSRectFill(NSMakeRect((NSWidth(dstRect)/2)+spacing, NSMinY(dstRect), NSWidth(dstRect)-spacing, NSHeight(dstRect)));
        return YES;
    }];
    [image setTemplate:YES];
    return image;
}


- (NSImage *)fastForwardImageWithSize:(NSSize)size
{
    NSImage *image = [NSImage IG_imageWithSize:size flipped:YES drawingHandler:^BOOL(NSRect dstRect) {
        NSBezierPath *path = [[NSBezierPath alloc] init];
        [path moveToPoint:NSMakePoint(NSMinX(dstRect), NSMinY(dstRect))];
        [path lineToPoint:NSMakePoint(NSMinX(dstRect), NSMaxY(dstRect))];
        [path lineToPoint:NSMakePoint(NSMidX(dstRect), NSMidY(dstRect))];
        [path lineToPoint:NSMakePoint(NSMidX(dstRect), NSMaxY(dstRect))]; // tri2
        [path lineToPoint:NSMakePoint(NSMaxX(dstRect), NSMidY(dstRect))];
        [path lineToPoint:NSMakePoint(NSMidX(dstRect), NSMinY(dstRect))];
        [path lineToPoint:NSMakePoint(NSMidX(dstRect), NSMidY(dstRect))];
        [path lineToPoint:NSMakePoint(NSMinX(dstRect), NSMinY(dstRect))];
        [path closePath];
        [[NSColor whiteColor] setFill];
        [path fill];
        return YES;
    }];
    [image setTemplate:YES];
    return image;
}

@end
