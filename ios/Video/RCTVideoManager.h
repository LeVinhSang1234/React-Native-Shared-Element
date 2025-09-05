//
//  RCTVideoManager.h
//  ShareVideo
//

#import <Foundation/Foundation.h>
#import <AVKit/AVKit.h>
#import <react/renderer/components/ShareElement/EventEmitters.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTVideoManager : NSObject

// State
@property (nonatomic, assign) BOOL loop;
@property (nonatomic, assign) BOOL muted;
@property (nonatomic, assign) BOOL paused;
@property (nonatomic, assign) BOOL enableProgress;
@property (nonatomic, assign) BOOL enableOnLoad;

@property (nonatomic, assign) double seek;
@property (nonatomic, assign) double volume;
@property (nonatomic, assign) double progressInterval;

@property (nonatomic, copy)   NSString *source;
@property (nonatomic, copy)   NSString *poster;            // poster URL/path (do RN truyền xuống)
@property (nonatomic, copy)   NSString *resizeMode;
@property (nonatomic, copy)   AVLayerVideoGravity aVLayerVideoGravity;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, assign) const facebook::react::VideoEventEmitter *eventEmitter;

// Callbacks to View
@property (nonatomic, copy, nullable) void (^onPosterUpdate)(UIImage * _Nullable image);
@property (nonatomic, copy, nullable) void (^onHiddenPoster)(void);

// Apply props from React
- (void)applySource:(NSString *)source;
- (void)applyPoster:(NSString *)poster;                 // NEW: nhận poster và tự tải
- (void)applyResizeMode:(NSString *)resizeMode;
- (void)applyPaused:(BOOL)paused;
- (void)applyPausedFromCommand:(BOOL)paused;
- (void)applyMuted:(BOOL)muted;
- (void)applyVolume:(double)volume;
- (void)applyVolumeFromCommand:(double)volume;
- (void)applySeek:(double)seek;
- (void)applyLoop:(BOOL)loop skipCheck:(BOOL)skipCheck;
- (void)applyProgressInterval:(double)interval;
- (void)applyProgress:(BOOL)enable;
- (void)applyOnLoad:(BOOL)enable;

// Player layer
- (void)createPlayerLayer;
- (void)setLayerFrame:(CGRect)bounds;

// Event emitter
- (void)updateEventEmitter:(const facebook::react::VideoEventEmitter *)eventEmitter;
- (void)seekToTime:(double)seek; // GIỮ LẠI cho command

// Share element: chuyển NGUYÊN player từ manager khác sang đây
- (void)adoptPlayerFromManager:(RCTVideoManager *)other;

// Giữ để tương thích (không khuyến nghị dùng nữa)
- (void)afterTargetShareElement:(AVPlayer *)otherPlayer
                  isOtherPaused:(BOOL)isOtherPaused __attribute__((deprecated("Use adoptPlayerFromManager:")));
- (void)detachPlayer;
// Lifecycle
- (void)willUnmount;
- (void)didUnmount;

@end

NS_ASSUME_NONNULL_END
