//
//  RCTVideoCache.m
//  ShareVideo
//
//  Created by Sang Le vinh on 8/19/25.
//

#import "RCTVideoCache.h"
#import "KTVHTTPCache/KTVHTTPCache.h"

@implementation RCTVideoCache

-(instancetype)init {
  self = [super init];
  return self;
}

+(NSInteger)VC_BytesFor:(double) seconds bitratebps:(double) bitratebps {
  if (bitratebps <= 0) bitratebps = 2e6;
  NSInteger bytes = (NSInteger)((bitratebps / 8.0) * seconds);
  return MAX(bytes, 128 * 1024);
}

+(void)VC_StartProxy {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSError *err = nil;
    [KTVHTTPCache proxyStart:&err]; // start global proxy 1 lần
    [KTVHTTPCache logSetConsoleLogEnable:NO];
    [KTVHTTPCache logSetRecordLogEnable:NO];

    if ([KTVHTTPCache respondsToSelector:@selector(logSetConsoleLogEnable:)]) {
      [KTVHTTPCache logSetConsoleLogEnable:NO];
    }
    // if (err) NSLog(@"[VideoView] proxyStart error: %@", err);
  });
}

+(void)VC_PrefetchHead:(NSURL *) url seconds:(double) seconds bitratebps:(double) bitratebps {
  NSInteger want = [self VC_BytesFor:seconds bitratebps:bitratebps];
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
  [req setValue:[NSString stringWithFormat:@"bytes=0-%ld", (long)(want - 1)]
forHTTPHeaderField:@"Range"];
  [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                   completionHandler:^(__unused NSData *data,
                                                       __unused NSURLResponse *resp,
                                                       __unused NSError *error) {
  }] resume];
}
@end
