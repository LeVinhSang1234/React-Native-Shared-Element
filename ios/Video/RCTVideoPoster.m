//
//  RCTVideoPoster.m
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import "RCTVideoPoster.h"
#import "RCTVideoHelper.h"

static NSString * const kResizeModeContain = @"contain";
static NSString * const kResizeModeCover   = @"cover";
static NSString * const kResizeModeStretch = @"stretch";
static NSString * const kResizeModeCenter  = @"center";

@interface RCTVideoPoster()
@property (nonatomic, copy) NSString *poster;
@property (nonatomic, copy) NSString *posterResizeMode;
@end

@implementation RCTVideoPoster

- (instancetype)init {
  if(self = [super init]) {
    self.userInteractionEnabled = NO;
    self.contentMode = UIViewContentModeScaleAspectFill;
    self.clipsToBounds = YES;
  }
  return self;
}

- (void)applyPoster:(NSString *)poster {
  if ((poster ?: @"") == (_poster ?: @"") || [poster isEqualToString:_poster]) return;
  _poster = poster ?: @"";
  
  NSURL *url = [RCTVideoHelper createPosterURL:_poster];
  __weak __typeof__(self) wSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSData *data = url ? [NSData dataWithContentsOfURL:url] : nil;
    dispatch_async(dispatch_get_main_queue(), ^{
      wSelf.image = data ? [UIImage imageWithData:data] : nil;
    });
  });
}

- (void)applyPosterResizeMode:(NSString *)posterResizeMode {
  if ([posterResizeMode isEqualToString:_posterResizeMode]) return;
  _posterResizeMode = posterResizeMode;
  
  if ([_posterResizeMode isEqualToString:kResizeModeContain]) {
    self.contentMode = UIViewContentModeScaleAspectFit;
  } else if ([_posterResizeMode isEqualToString:kResizeModeCover]) {
    self.contentMode = UIViewContentModeScaleAspectFill;
  } else if ([_posterResizeMode isEqualToString:kResizeModeStretch]) {
    self.contentMode = UIViewContentModeScaleToFill;
  } else if ([_posterResizeMode isEqualToString:kResizeModeCenter]) {
    self.contentMode = UIViewContentModeCenter;
  } else self.contentMode = UIViewContentModeScaleAspectFill;
}

- (void)dealloc {
  self.image = nil;
  self.hidden = YES;
  _poster = nil;
  _posterResizeMode = nil;
}

@end
