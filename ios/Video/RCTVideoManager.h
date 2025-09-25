//
//  RCTVideoManager.h
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import <Foundation/Foundation.h>
#import <AVKit/AVKit.h>
#import <react/renderer/components/ShareElement/EventEmitters.h>

NS_ASSUME_NONNULL_BEGIN
@interface RCTVideoManager : NSObject
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, copy) AVLayerVideoGravity aVLayerVideoGravity;
@property (nonatomic, assign) BOOL paused;
@property (nonatomic, copy, nullable) void (^onPlayerReady)(void);

- (void)applySource:(NSString *)source;
- (void)applyResizeMode:(NSString *)resizeMode;
- (void)applyPaused:(BOOL)paused;
- (void)applyPausedFromCommand:(BOOL)paused;
- (void)applyMuted:(BOOL)muted;
- (void)applyVolume:(double)volume;
- (void)applyVolumeFromCommand:(double)volume;
- (void)applySeek:(double)seek;
- (void)applyLoop:(BOOL)loop;
- (void)applyLoopFromCommand:(BOOL)loop;
- (void)applyProgressInterval:(double)interval;
- (void)applyProgress:(BOOL)enable;
- (void)applyOnLoad:(BOOL)enable;

- (void)ensurePlayerLayerWithBounds:(CGRect)bounds;
- (void)updateEventEmitter:(const facebook::react::VideoEventEmitter *)eventEmitter;
- (void)seekToTime:(double)seek;


// Share element: chuyển NGUYÊN player từ manager khác sang đây
- (void)adoptPlayerFromManager:(RCTVideoManager *)other;
- (void)detachPlayer;

- (void)willUnmount;
- (void)unmount;

@end
NS_ASSUME_NONNULL_END
