//
//  RCTVideoManager.h
//  ShareVideo
//
//  Created by Sang Le vinh on 8/19/25.
//
#import <Foundation/Foundation.h>
#import "AVKit/AVKit.h"
#import <react/renderer/components/Video/EventEmitters.h>

NS_ASSUME_NONNULL_BEGIN
@interface RCTVideoManager : NSObject

@property (nonatomic, assign) id timeObserver;
@property (nonatomic, assign) NSTimer *loadEventTimer;

@property (nonatomic, assign) BOOL loop;
@property (nonatomic, assign) BOOL muted;
@property (nonatomic, assign) BOOL paused;
@property (nonatomic, assign) BOOL enableProgress;
@property (nonatomic, assign) BOOL enableOnLoad;

@property (nonatomic, assign) double seek;
@property (nonatomic, assign) double volume;
@property (nonatomic, assign) double progressInterval;
@property (nonatomic, assign) double lastLoadedDuration;

@property (nonatomic, copy) NSString *source;
@property (nonatomic, copy) NSString *poster;
@property (nonatomic, copy) NSString *resizeMode;
@property (nonatomic, copy) AVLayerVideoGravity aVLayerVideoGravity;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, assign) const facebook::react::VideoEventEmitter *eventEmitter;

- (void)applyMuted:(BOOL)muted;
- (void)applyPaused:(BOOL)paused;
- (void)applySource:(NSString *)source;
- (void)applyResizeMode:(NSString *)resizeMode;
- (void)setLayerFrame:(CGRect) bounds;
- (void)applyOnLoad:(BOOL) enableOnLoad;
- (void)applyProgress:(BOOL) enableProgress;
- (void)createPlayerLayer;
- (void)updateEventEmitter:(const facebook::react::VideoEventEmitter *)eventEmitter;
- (void)applyProgressInterval:(double) progressInterval;
- (void)applySeek:(double) seek;
- (void)seekToTime:(double)seek;
- (void)applyVolume:(double)volume;
- (void)applyVolumeFromCommand:(double)volume;
- (void)applyPausedFromCommand:(BOOL)paused;

- (void)beforeShareElement;
- (void)afterShareElementComplete;

- (void)beforeTargetShareElement;
- (void)afterTargetShareElement:(AVPlayer *)otherPlayer isOtherPaused:(BOOL) isOtherPaused;

- (void) unmount;
- (void)beforeUnmount;

@end
NS_ASSUME_NONNULL_END
