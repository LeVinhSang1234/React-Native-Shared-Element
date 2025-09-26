//
//  FullscreenVideoViewController.m
//  shareelement
//
//  Created by Sang Le vinh on 9/25/25.
//

#import <Foundation/Foundation.h>
#import "FullscreenVideoViewController.h"

@interface FullscreenVideoViewController ()
@property (nonatomic, strong) UIView *container;
@end

@implementation FullscreenVideoViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.blackColor;

  self.container = [[UIView alloc] initWithFrame:self.view.bounds];
  self.container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.container.backgroundColor = UIColor.blackColor;
  [self.view addSubview:self.container];
}

- (UIView *)videoContainer {
  return self.container;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
  return self.landscape ? UIInterfaceOrientationMaskLandscape
                        : UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate {
  return YES;
}

@end
