//
//  RCTContainerPoster.m
//  shareelement
//
//  Created by Sang Le vinh on 9/26/25.
//

#import "RCTContainerPoster.h"

@implementation RCTContainerPoster

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.userInteractionEnabled = YES;
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  for (CALayer *layer in self.layer.sublayers) {
    layer.frame = self.bounds;
  }
  [CATransaction commit];
}

@end
