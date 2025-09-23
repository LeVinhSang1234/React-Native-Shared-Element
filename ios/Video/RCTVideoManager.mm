//
//  RCTVideoManager.m
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import "RCTVideoManager.h"
#import "RCTVideoHelper.h"

static NSString * const kResizeModeContain = @"contain";
static NSString * const kResizeModeCover   = @"cover";
static NSString * const kResizeModeStretch = @"stretch";
static NSString * const kResizeModeCenter  = @"center";

@interface RCTVideoManager()
@property (nonatomic, assign) const facebook::react::VideoEventEmitter *eventEmitter;

@property (nonatomic, copy) NSString *source;
@property (nonatomic, copy) NSString *resizeMode;
@property (nonatomic, assign) BOOL loop;
@property (nonatomic, assign) BOOL muted;
@property (nonatomic, assign) BOOL enableProgress;
@property (nonatomic, assign) BOOL enableOnLoad;
@property (nonatomic, assign) double seek;
@property (nonatomic, assign) double volume;
@property (nonatomic, assign) double progressInterval;

@end

@implementation RCTVideoManager {
  id _timeObserver;
  NSTimer *_loadEventTimer;
  double _lastLoadedDuration;
}

- (instancetype)init {
  if (self = [super init]) {
    _aVLayerVideoGravity = AVLayerVideoGravityResizeAspect;
    _volume = 1.0;
  }
  return self;
}

#pragma mark - Apply props from React

- (void)applySource:(NSString *)source {
  if ([source isEqualToString:_source]) return;
  
  [self willUnmount];
  NSURL *videoURL = [RCTVideoHelper createVideoURL:source];
  _player = [AVPlayer playerWithURL:videoURL];
  
  [self trackEventsPlayer];
  [self createPlayerLayer];
  
  if (!_paused) [_player play];
  _source = source;
}

- (void)applyResizeMode:(NSString *)resizeMode {
  if ([resizeMode isEqualToString:_resizeMode]) return;
  _aVLayerVideoGravity = [self videoGravityFromResizeMode:resizeMode];
  if (_playerLayer) _playerLayer.videoGravity = _aVLayerVideoGravity;
  _resizeMode = resizeMode;
}

- (void)applyPaused:(BOOL)paused {
  if (paused == _paused) return;
  [self applyPausedFromCommand:paused];
  _paused = paused;
}

- (void)applyPausedFromCommand:(BOOL)paused {
  __weak __typeof__(self) weakSelf = self;
  if (paused) {
    [_player setMuted:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [weakSelf.player pause]; });
  } else {
    [_player play];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [weakSelf.player setMuted:weakSelf.muted]; });
  }
}

- (void)applyMuted:(BOOL)muted {
  if (muted == _muted) return;
  _muted = muted;
  [_player setMuted:muted];
}

- (void)applyVolume:(double)volume {
  if (volume == _volume) return;
  [self applyVolumeFromCommand:volume];
  _volume = volume;
}

- (void)applyVolumeFromCommand:(double)volume {
  double clamped = fmax(0.0, fmin(1.0, volume));
  [_player setVolume:clamped];
}

- (void)applySeek:(double)seek {
  if (seek == _seek) return;
  [self seekToTime:seek];
  _seek = seek;
}

- (void)seekToTime:(double)seek {
  if (!_player || !_player.currentItem || _player.currentItem.status != AVPlayerItemStatusReadyToPlay) return;
  
  CMTime seekTime = CMTimeMakeWithSeconds(seek, NSEC_PER_SEC);
  CMTime duration = _player.currentItem.duration;
  if (CMTIME_IS_VALID(duration) && CMTimeCompare(seekTime, duration) > 0) {
    seekTime = duration;
  }
  [_player seekToTime:seekTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:{}];
}

- (void)applyLoop:(BOOL)loop {
  if (loop == _loop) return;
  [self applyLoopFromCommand:loop];
}

- (void)applyLoopFromCommand:(BOOL)loop {
  if (loop && _player && _player.currentItem) {
    double cur = CMTimeGetSeconds(_player.currentTime);
    double dur = CMTimeGetSeconds(_player.currentItem.duration);
    if (dur > 0 && cur >= dur) {
      [_player seekToTime:kCMTimeZero];
      [self applyPaused:_paused];
    }
  }
  _loop = loop;
}

- (void)applyProgressInterval:(double)interval {
  if (interval == _progressInterval) return;
  _progressInterval = interval;
  if (_enableProgress) [self addProgressTracking];
}

- (void)applyProgress:(BOOL)enable {
  if (enable == _enableProgress) return;
  enable ? [self addProgressTracking] : [self removeProgressTracking];
  _enableProgress = enable;
}

- (void)applyOnLoad:(BOOL)enable {
  if (enable == _enableOnLoad) return;
  enable ? [self addOnLoadTracking] : [self removeOnLoadTracking];
  _enableOnLoad = enable;
}

#pragma mark - Player layer

- (void)ensurePlayerLayerWithBounds:(CGRect)bounds {
  if (!_playerLayer) {
    [self createPlayerLayer];
    [self applyResizeMode:_resizeMode];
  }
  _playerLayer.frame = bounds;
}

- (void)createPlayerLayer {
  if (_player && !_playerLayer) {
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    if (_aVLayerVideoGravity) _playerLayer.videoGravity = _aVLayerVideoGravity;
  }
}

- (AVLayerVideoGravity)videoGravityFromResizeMode:(NSString *)resizeMode {
  if ([resizeMode isEqualToString:kResizeModeCover]) {
    return AVLayerVideoGravityResizeAspectFill;
  } else if ([resizeMode isEqualToString:kResizeModeStretch]) {
    return AVLayerVideoGravityResize;
  } else if ([resizeMode isEqualToString:kResizeModeCenter]) {
    return AVLayerVideoGravityResizeAspect;
  } else { // contain/default
    return AVLayerVideoGravityResizeAspect;
  }
}

#pragma mark - Event emitter

- (void)updateEventEmitter:(const facebook::react::VideoEventEmitter *)eventEmitter {
  _eventEmitter = eventEmitter;
}

#pragma mark - Trackers

- (void)addOnLoadTracking {
  if (!_player) return;
  [self removeOnLoadTracking];
  _loadEventTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                     target:self
                                                   selector:@selector(sendOnLoadEvent)
                                                   userInfo:nil
                                                    repeats:YES];
  [[NSRunLoop mainRunLoop] addTimer:_loadEventTimer forMode:NSRunLoopCommonModes];
}

- (void)removeOnLoadTracking {
  if (_loadEventTimer) {
    [_loadEventTimer invalidate];
    _loadEventTimer = nil;
  }
}

- (void)addProgressTracking {
  if (!_player) return;
  [self removeProgressTracking];
  __weak __typeof__(self) weakSelf = self;
  double intervalSeconds = (_progressInterval == 0 ? 1.0 : _progressInterval / 1000.0);
  _timeObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(intervalSeconds, NSEC_PER_SEC)
                                                        queue:dispatch_get_main_queue()
                                                   usingBlock:^(__unused CMTime t) {
    [weakSelf sendProgressEvent];
  }];
}

- (void)removeProgressTracking {
  if (_timeObserver && _player) {
    [_player removeTimeObserver:_timeObserver];
    _timeObserver = nil;
  }
}

#pragma mark - Events

- (void)playerItemDidFailToPlayToEnd:(NSNotification *)notification {
  NSError *error = notification.userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey];
  [self sendOnErrorEvent:error];
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
  if (!_player) return;
  [self sendEndEvent];
  if (_loop) {
    [_player seekToTime:kCMTimeZero];
    [self applyPaused:_paused];
  }
}

- (void)sendOnErrorEvent:(NSError *)error {
  if (_eventEmitter && error) {
    NSString *codeString = [NSString stringWithFormat:@"%ld", (long)error.code];
    facebook::react::VideoEventEmitter::OnError data = {
      .message = [error.localizedDescription ?: @"Unknown error" UTF8String],
      .code = [codeString UTF8String],
    };
    _eventEmitter->onError(data);
  }
}

- (void)sendProgressEvent {
  if (!_player || !_player.currentItem) return;
  
  CMTime currentTime = _player.currentTime;
  CMTime duration = _player.currentItem.duration;
  
  double currentSeconds = CMTimeGetSeconds(currentTime);
  double durationSeconds = CMTimeGetSeconds(duration);
  double playableDuration = 0.0;
  
  if (isnan(currentSeconds)) currentSeconds = 0.0;
  if (isnan(durationSeconds)) durationSeconds = 0.0;
  
  NSArray *loadedTimeRanges = _player.currentItem.loadedTimeRanges;
  if (loadedTimeRanges.count > 0) {
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];
    playableDuration = CMTimeGetSeconds(CMTimeRangeGetEnd(timeRange));
  }
  if (isnan(playableDuration)) playableDuration = 0.0;
  
  if (_eventEmitter) {
    facebook::react::VideoEventEmitter::OnProgress data = {
      .currentTime = currentSeconds,
      .duration = durationSeconds,
      .playableDuration = playableDuration
    };
    _eventEmitter->onProgress(data);
  }
}

- (void)sendEndEvent {
  if (!_player || !_player.currentItem) return;
  if (_eventEmitter) {
    facebook::react::VideoEventEmitter::OnEnd data = {};
    _eventEmitter->onEnd(data);
  }
}

- (void)sendLoadStartEvent {
  if (!_player || !_player.currentItem) return;
  
  double durationSeconds = CMTimeGetSeconds(_player.currentItem.duration);
  if (isnan(durationSeconds)) durationSeconds = 0.0;
  
  if (_seek > 0 && durationSeconds > 0) {
    double seekValue = MIN(_seek, durationSeconds);
    CMTime seekTime = CMTimeMakeWithSeconds(seekValue, NSEC_PER_SEC);
    [_player seekToTime:seekTime];
  }
  
  double playableDuration = 0.0;
  NSArray *loadedTimeRanges = _player.currentItem.loadedTimeRanges;
  if (loadedTimeRanges.count > 0) {
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];
    playableDuration = CMTimeGetSeconds(CMTimeRangeGetEnd(timeRange));
  }
  if (isnan(playableDuration)) playableDuration = 0.0;
  
  CGSize videoSize = CGSizeZero;
  NSArray *tracks = [_player.currentItem.asset tracksWithMediaType:AVMediaTypeVideo];
  if (tracks.count > 0) {
    AVAssetTrack *videoTrack = tracks.firstObject;
    videoSize = videoTrack.naturalSize;
  }
  
  if (_eventEmitter) {
    facebook::react::VideoEventEmitter::OnLoadStart data = {
      .duration = durationSeconds,
      .playableDuration = playableDuration,
      .width = videoSize.width,
      .height = videoSize.height
    };
    _eventEmitter->onLoadStart(data);
  }
}

- (void)sendOnLoadEvent {
  if (!_player || !_player.currentItem) return;
  
  double duration = CMTimeGetSeconds(_player.currentItem.duration);
  if (isnan(duration)) duration = 0.0;
  
  double loadedDuration = 0.0;
  NSArray *loadedTimeRanges = _player.currentItem.loadedTimeRanges;
  if (loadedTimeRanges.count > 0) {
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];
    loadedDuration = CMTimeGetSeconds(CMTimeRangeGetEnd(timeRange));
    if (isnan(loadedDuration)) loadedDuration = 0.0;
  }
  
  if (loadedDuration != _lastLoadedDuration) {
    _lastLoadedDuration = loadedDuration;
    if (_eventEmitter) {
      facebook::react::VideoEventEmitter::OnLoad data = {
        .loadedDuration = loadedDuration,
        .duration = duration
      };
      _eventEmitter->onLoad(data);
    }
  }
}

- (void)sendBufferingEvent:(BOOL)buffering {
  if (_eventEmitter) {
    facebook::react::VideoEventEmitter::OnBuffering data = { .isBuffering = buffering };
    _eventEmitter->onBuffering(data);
  }
}

#pragma mark - Share element (move player, no seek)

- (void)adoptPlayerFromManager:(RCTVideoManager *)other {
  if (!other || other == self) return;
  
  AVPlayer *movingPlayer = other.player;
  if (!movingPlayer) return;
  @try {
    if (other.playerLayer) {
      [other.playerLayer removeFromSuperlayer];
    }
  } @catch (__unused NSException *e) {}
  
  @try { [other removeProgressTracking]; } @catch (__unused NSException *e) {}
  @try { [other removeOnLoadTracking]; }   @catch (__unused NSException *e) {}
  @try { [other safeRemoveObservers]; }    @catch (__unused NSException *e) {}
  
  @try {
    if (_playerLayer) {
      [_playerLayer removeFromSuperlayer];
      _playerLayer = nil;
    }
  } @catch (__unused NSException *e) {}
  
  _player = movingPlayer;
  [self createPlayerLayer];
  if (_playerLayer && _playerLayer.superlayer == nil) {
  }
  
  if (_playerLayer) _playerLayer.videoGravity = _aVLayerVideoGravity;
  [self applyVolumeFromCommand:_volume];
  [self applyLoopFromCommand:_loop];
  [self applyPausedFromCommand:_paused];
}

- (void)detachPlayer {
  if (self.playerLayer.superlayer) {
    [self.playerLayer removeFromSuperlayer];
  }
  _playerLayer = nil;
  _player = nil;
}

// Internal: gỡ sạch other, trả về player (không đổi trạng thái play/pause)
- (AVPlayer *)_stealPlayerAndDetach {
  if (!_player) return nil;
  
  // timers
  [self removeProgressTracking];
  [self removeOnLoadTracking];
  
  // observers & notifications
  [self safeRemoveObservers];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  // layer
  if (_playerLayer) {
    [_playerLayer removeFromSuperlayer];
    _playerLayer = nil;
  }
  
  AVPlayer *stolen = _player;
  _player = nil;
  return stolen;
}

// Internal: attach player + layer + observers + timers theo flags hiện tại
- (void)_attachStolenPlayer:(AVPlayer *)stolen {
  _player = stolen;
  
  [self createPlayerLayer];
  [self trackEventsPlayer];
  
  if (_enableOnLoad)   [self addOnLoadTracking];
  if (_enableProgress) [self addProgressTracking];
}


#pragma mark - Observers

- (void)trackEventsPlayer {
  AVPlayerItem *item = _player.currentItem;
  if (!item) return;
  
  [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
  [item addObserver:self forKeyPath:@"error" options:NSKeyValueObservingOptionNew context:nil];
  [item addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
  [item addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidFailToPlayToEnd:)
                                               name:AVPlayerItemFailedToPlayToEndTimeNotification object:item];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:)
                                               name:AVPlayerItemDidPlayToEndTimeNotification object:item];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if (object != _player.currentItem) return;
  
  if ([keyPath isEqualToString:@"status"] && _player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
    [self sendLoadStartEvent];
    [_player.currentItem removeObserver:self forKeyPath:@"status"];
  } else if ([keyPath isEqualToString:@"error"]) {
    [self sendOnErrorEvent:_player.currentItem.error];
  } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
    [self sendBufferingEvent:YES];
  } else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
    [self sendBufferingEvent:NO];
  }
}

- (void)safeRemoveObservers {
  AVPlayerItem *item = _player.currentItem;
  if (!item) return;
  @try { [item removeObserver:self forKeyPath:@"status"]; } @catch (__unused NSException *e) {}
  @try { [item removeObserver:self forKeyPath:@"error"]; } @catch (__unused NSException *e) {}
  @try { [item removeObserver:self forKeyPath:@"playbackBufferEmpty"]; } @catch (__unused NSException *e) {}
  @try { [item removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"]; } @catch (__unused NSException *e) {}
}

#pragma mark - Cleanup

- (void)willUnmount {
  [self removeProgressTracking];
  [self removeOnLoadTracking];
  [self safeRemoveObservers];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  _source = @"";
  _seek = 0;
  _paused = NO;
  _muted = NO;
  _volume = 1.0;
  _loop = NO;
  _resizeMode = @"contain";
  _progressInterval = 0;
  _enableProgress = NO;
  _enableOnLoad = NO;
  _lastLoadedDuration = 0;
  _eventEmitter = nil;
  
  if (_playerLayer) {
    [_playerLayer removeFromSuperlayer];
    _playerLayer = nil;
  }
}

- (void)unmount {
  if (_player) {
    [_player pause];
    _player = nil;
  }
}

@end
