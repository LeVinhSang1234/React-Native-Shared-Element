//
//  RCTVideoManager.m
//  ShareVideo
//
//  Created by Sang Le vinh on 8/19/25.
//
#import "RCTVideoManager.h"
#import "RCTVideoHelper.h"

static NSString * const kResizeModeContain = @"contain";
static NSString * const kResizeModeCover = @"cover";
static NSString * const kResizeModeStretch = @"stretch";
static NSString * const kResizeModeCenter = @"center";

@implementation RCTVideoManager

- (instancetype)init {
  self = [super init];
  _aVLayerVideoGravity = AVLayerVideoGravityResizeAspect;
  return self;
}

- (void)applySource:(NSString *)source
{
  if([source isEqualToString:_source]) return;
  [self unmount];
  NSURL *videoURL = [RCTVideoHelper createVideoURL:source];
  _player = [AVPlayer playerWithURL:videoURL];
  
  [self trackEventsPlayer];
  [self createPlayerLayer];
  if(!_paused) [_player play];
  _source = source;
}

- (void)createPlayerLayer
{
  if (_player && !_playerLayer ) {
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    if(_aVLayerVideoGravity) _playerLayer.videoGravity = _aVLayerVideoGravity;
  }
}

- (void)applyResizeMode:(NSString *)resizeMode {
  if([resizeMode isEqualToString:_resizeMode]) return;
  if(_playerLayer) {
    _aVLayerVideoGravity = [self videoGravityFromResizeMode:resizeMode];
    _playerLayer.videoGravity = _aVLayerVideoGravity;
  }
  _resizeMode = resizeMode;
}

- (void)applyPaused:(BOOL)paused {
  if(paused == _paused) return;
  [self applyPausedFromCommand:paused];
  _paused = paused;
}

- (void)applyPausedFromCommand:(BOOL)paused {
  __weak RCTVideoManager *weakSelf = self;
  if(paused) {
    [_player setMuted:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [weakSelf.player pause];
    });
  } else {
    [_player play];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [weakSelf.player setMuted:weakSelf.muted];
    });
  }
}

- (void)applyMuted:(BOOL)muted
{
  if(muted == _muted) return;
  [_player setMuted:muted];
  _muted = muted;
}

// -------- VOLUME --------- //
- (void)applyVolume:(double)volume;
{
  if(volume == _volume) return;
  
  [self applyVolumeFromCommand:volume];
  _volume = volume;
}

- (void)applyVolumeFromCommand:(double)volume {
  double clampedVolume = volume;
  if (clampedVolume < 0.0) clampedVolume = 0.0;
  if (clampedVolume > 1.0) clampedVolume = 1.0;
  
  [_player setVolume:clampedVolume];
}
// -------- VOLUME --------- //

// -------- SEEK --------- //
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
  [_player seekToTime:seekTime
      toleranceBefore:kCMTimeZero
       toleranceAfter:kCMTimeZero
    completionHandler:^(BOOL finished) {
  }];
  // TODO handle poster with seek = 0;
}
// -------- SEEK --------- //

// -------- LOOP --------- //
- (void)applyLoop:(BOOL)loop {
  if(loop == _loop) return;
  if (loop && _player && _player.currentItem) {
    CMTime currentTime = _player.currentTime;
    CMTime duration = _player.currentItem.duration;
    double currentSeconds = CMTimeGetSeconds(currentTime);
    double durationSeconds = CMTimeGetSeconds(duration);
    if (durationSeconds > 0 && currentSeconds >= durationSeconds) {
      [_player seekToTime:kCMTimeZero];
      [self applyPaused:_paused];
    }
  }
  _loop = loop;
}
// -------- LOOP --------- //

// -------- PROGRESS --------- //
- (void)applyProgressInterval:(double) progressInterval {
  if(progressInterval == _progressInterval) return;
  [self setProgressInterval:progressInterval];
  if(_enableProgress) [self addProgressTracking];
}

- (void)applyProgress:(BOOL) enableProgress {
  if(enableProgress == _enableProgress) return;
  
  if(enableProgress) [self addProgressTracking];
  else [self removeProgressTracking];
  
  [self setEnableProgress:enableProgress];
}
// -------- PROGRESS --------- //

// -------- ONLOAD --------- //
- (void)applyOnLoad:(BOOL) enableOnLoad {
  if(enableOnLoad == _enableOnLoad) return;
  
  if(enableOnLoad) [self addOnLoadTracking];
  else [self removeOnLoadTracking];
  
  [self setEnableOnLoad:enableOnLoad];
}
// -------- ONLOAD --------- //

#pragma mark - LAYOUT CONFIG

// -------- RESIZE MODE --------- //
- (AVLayerVideoGravity)videoGravityFromResizeMode:(NSString *)resizeMode {
  if ([resizeMode isEqualToString:kResizeModeCover]) {
    return AVLayerVideoGravityResizeAspectFill;
  } else if ([resizeMode isEqualToString:kResizeModeStretch]) {
    return AVLayerVideoGravityResize;
  } else if ([resizeMode isEqualToString:kResizeModeCenter]) {
    return AVLayerVideoGravityResizeAspect;
  } else { // contain or default
    return AVLayerVideoGravityResizeAspect;
  }
}

// -------- TODO POSTER --------- //
- (UIViewContentMode)contentModeFromResizeMode:(NSString *)resizeMode {
  if ([resizeMode isEqualToString:kResizeModeCover]) {
    return UIViewContentModeScaleAspectFill;
  } else if ([resizeMode isEqualToString:kResizeModeStretch]) {
    return UIViewContentModeScaleToFill;
  } else if ([resizeMode isEqualToString:kResizeModeCenter]) {
    return UIViewContentModeCenter;
  } else { // contain or default
    return UIViewContentModeScaleAspectFit;
  }
}

#pragma mark - ADD LISTEN OBSERVER
- (void) trackEventsPlayer {
  [_player.currentItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
  [_player.currentItem addObserver:self forKeyPath:@"error" options:NSKeyValueObservingOptionNew context:nil];
  [_player.currentItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
  [_player.currentItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(playerItemDidFailToPlayToEnd:)
                                               name:AVPlayerItemFailedToPlayToEndTimeNotification
                                             object:_player.currentItem];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(playerItemDidReachEnd:)
                                               name:AVPlayerItemDidPlayToEndTimeNotification
                                             object:_player.currentItem];
}

#pragma mark - FABRIC EMITTER

- (void)setLayerFrame:(CGRect) bounds {
  _playerLayer.frame = bounds;
}

- (void)updateEventEmitter:(const facebook::react::VideoEventEmitter *)eventEmitter {
  _eventEmitter = eventEmitter;
}


#pragma mark - FUNCTION

// -------- ONLOAD TRACKING --------- //
- (void)removeOnLoadTracking {
  if (_loadEventTimer) {
    [_loadEventTimer invalidate];
    _loadEventTimer = nil;
  }
}

- (void)addOnLoadTracking {
  if (!_player) return;
  
  [self removeOnLoadTracking];
  _loadEventTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                     target:self
                                                   selector:@selector(sendOnLoadEvent)
                                                   userInfo:nil
                                                    repeats:YES];
}
// -------- ONLOAD TRACKING --------- //

// -------- PROGRESS TRACKING --------- //
- (void)removeProgressTracking {
  if (_timeObserver && _player) {
    [_player removeTimeObserver:_timeObserver];
    _timeObserver = nil;
  }
}

- (void)addProgressTracking {
  if (!_player) return;
  [self removeProgressTracking];
  
  __weak RCTVideoManager *weakSelf = self;
  double intervalMs = (_progressInterval == 0) ? 1.0 : _progressInterval;
  double intervalSeconds = intervalMs / 1000.0;
  
  _timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(intervalSeconds, NSEC_PER_SEC)
                                                            queue:dispatch_get_main_queue()
                                                       usingBlock:^(CMTime time) {
    [weakSelf sendProgressEvent];
  }];
}
// -------- PROGRESS TRACKING --------- //

#pragma mark - Share Element
- (void)beforeShareElement {
  [_player setMuted:_muted];
  if(!_paused) [_player play];
  if (_playerLayer) {
    [_playerLayer removeFromSuperlayer];
    _playerLayer = nil;
  }
}

- (void)afterShareElementComplete {
  [_player setMuted:TRUE];
  [_player pause];
}

- (void)beforeTargetShareElement {
  [_player setMuted:TRUE];
  [_player pause];
}

- (void)afterTargetShareElement:(AVPlayer *)otherPlayer isOtherPaused:(BOOL) isOtherPaused {
  if(!otherPlayer) return;
  
  double currentSeconds = CMTimeGetSeconds(otherPlayer.currentTime) + 0.2;
  double durationSeconds = CMTimeGetSeconds(otherPlayer.currentItem.duration);
  BOOL isEnded = (durationSeconds > 0) && (currentSeconds >= durationSeconds);
  
  if(!isEnded) {
    [self seekToTime:currentSeconds];
  }
  [_player setMuted:_muted];
  if(!_paused) [_player play];
  [otherPlayer setMuted:YES];
}

#pragma mark - LISTEN OBSERVE VALUE

- (void)playerItemDidFailToPlayToEnd:(NSNotification *)notification {
  NSError *error = notification.userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey];
  [  self sendOnErrorEvent:error  ];
}

- (void)sendOnErrorEvent:(NSError *)error {
  if(_eventEmitter && error) {
    NSString *codeString = [NSString stringWithFormat:@"%ld", (long)error.code];
    
    facebook::react::VideoEventEmitter::OnError data = {
      .message = [error.localizedDescription ?: @"Unknown error" UTF8String],
      .code = [codeString UTF8String],
    };
    _eventEmitter->onError(data);
  }
}

- (void)sendProgressEvent {
  if (!_player || !_player.currentItem) {
    return;
  }
  
  CMTime currentTime = _player.currentTime;
  CMTime duration = _player.currentItem.duration;
  
  double currentSeconds = CMTimeGetSeconds(currentTime);
  double durationSeconds = CMTimeGetSeconds(duration);
  double playableDuration = 0.0;
  
  // Handle NaN values
  if (isnan(currentSeconds))
    currentSeconds = 0.0;
  if (isnan(durationSeconds))
    durationSeconds = 0.0;
  
  // Calculate playable duration
  NSArray *loadedTimeRanges =
  _player.currentItem.loadedTimeRanges;
  if (loadedTimeRanges.count > 0) {
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];
    playableDuration = CMTimeGetSeconds(CMTimeRangeGetEnd(timeRange));
  }
  
  if (isnan(playableDuration)) playableDuration = 0.0;
  
  // Send event using Fabric EventEmitter
  if(_eventEmitter) {
    facebook::react::VideoEventEmitter::OnProgress data = {
      .currentTime = currentSeconds,
      .duration = durationSeconds,
      .playableDuration = playableDuration};
    
    _eventEmitter->onProgress(data);
  }
}

- (void) sendEndEvent
{
  if (!_player || !_player.currentItem) return;
  
  CMTime duration = self.player.currentItem.duration;
  double durationSeconds = CMTimeGetSeconds(duration);
  
  if (isnan(durationSeconds)) durationSeconds = 0.0;
  
  if (_eventEmitter) {
    facebook::react::VideoEventEmitter::OnEnd data = {};
    _eventEmitter->onEnd(data);
  }
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
  if(!_player) return;
  
  [self sendEndEvent];
  
  if (_loop) {
    [_player seekToTime:kCMTimeZero];
    [self applyPaused:_paused];
  }
}

- (void) sendLoadStartEvent
{
  if (!_player || !_player.currentItem) return;
  
  CMTime duration = self.player.currentItem.duration;
  double durationSeconds = CMTimeGetSeconds(duration);;
  if (isnan(durationSeconds)) durationSeconds = 0.0;
  if (_seek > 0 && durationSeconds > 0) {
    double seekValue = _seek;
    if (seekValue > durationSeconds) seekValue = durationSeconds;
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
  if (_player.currentItem && _player.currentItem.asset) {
    NSArray *tracks = [_player.currentItem.asset tracksWithMediaType:AVMediaTypeVideo];
    if (tracks.count > 0) {
      AVAssetTrack *videoTrack = tracks.firstObject;
      videoSize = videoTrack.naturalSize;
    }
  }
  
  facebook::react::VideoEventEmitter::OnLoadStart data = {
    .duration = durationSeconds,
    .playableDuration = playableDuration,
    .width = videoSize.width,
    .height = videoSize.height
  };
  if (_eventEmitter) {
    _eventEmitter->onLoadStart(data);
  }
}

- (void)sendOnLoadEvent {
  if (!_player || !_player.currentItem) return;
  
  double loadedDuration = 0.0;
  double duration = 0.0;
  CMTime durationTime = _player.currentItem.duration;
  duration = CMTimeGetSeconds(durationTime);
  if (isnan(duration)) duration = 0.0;
  NSArray *loadedTimeRanges = _player.currentItem.loadedTimeRanges;
  if (loadedTimeRanges.count > 0) {
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];
    loadedDuration = CMTimeGetSeconds(CMTimeRangeGetEnd(timeRange));
    if (isnan(loadedDuration)) loadedDuration = 0.0;
  }
  if (loadedDuration != _lastLoadedDuration) {
    [self setLastLoadedDuration:loadedDuration];
    
    if (_eventEmitter) {
      facebook::react::VideoEventEmitter::OnLoad data = {
        .loadedDuration = loadedDuration,
        .duration = duration
      };
      _eventEmitter->onLoad(data);
    }
  }
}

- (void)sendBufferingEvent:(BOOL) buffering {
  if (_eventEmitter) {
    facebook::react::VideoEventEmitter::OnBuffering data = {
      .isBuffering = buffering
    };
    _eventEmitter->onBuffering(data);
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if(object != _player.currentItem) return;
  
  if ([keyPath isEqualToString:@"status"]) {
    if (self.player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
      [self sendLoadStartEvent];
      [self.player.currentItem removeObserver:self forKeyPath:@"status"];
    }
  } else if ([keyPath isEqualToString:@"error"] ) {
    NSError *error = _player.currentItem.error;
    [self sendOnErrorEvent:error];
  } else if ([keyPath isEqualToString:@"playbackBufferEmpty"] ) {
    [self sendBufferingEvent:YES];
  } else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"] ) {
    [self sendBufferingEvent:NO];
  }
}

#pragma mark - CLEAN

- (void)beforeUnmount {
  [self removeProgressTracking];
  [self removeOnLoadTracking];
  
  AVPlayerItem *oldItem = _player.currentItem;
  if (oldItem) {
    @try { [oldItem removeObserver:self forKeyPath:@"status"]; } @catch (__unused NSException *e) {}
    @try { [oldItem removeObserver:self forKeyPath:@"error"]; } @catch (__unused NSException *e) {}
    @try { [oldItem removeObserver:self forKeyPath:@"playbackBufferEmpty"]; } @catch (__unused NSException *e) {}
    @try { [oldItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"]; } @catch (__unused NSException *e) {}
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemFailedToPlayToEndTimeNotification
                                                  object:oldItem];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:oldItem];
  }
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:AVPlayerItemDidPlayToEndTimeNotification
                                                object:nil];
  
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
  
  if(_playerLayer) {
    [_playerLayer removeFromSuperlayer];
    _playerLayer = nil;
  }
}

- (void) dealloc
{
  [self beforeUnmount];
  [self unmount];
}

- (void)unmount {
  if(_player) {
    [_player pause];
    _player = nil;
  }
}


@end
