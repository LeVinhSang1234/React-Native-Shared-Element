//
//  RCTVideoCache.m
//  shareelement
//
//  Created by Sang Le vinh on 9/23/25.
//

#import "RCTVideoCache.h"
#import "KTVHTTPCache/KTVHTTPCache.h"

static double maxSizeMB = 200; // 200MB

@implementation RCTVideoCache

-(instancetype)init {
  self = [super init];
  return self;
}

+ (NSString *)VC_CacheDir {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
  NSString *cachesDir = [paths firstObject];
  return [cachesDir stringByAppendingPathComponent:@"KTVHTTPCache"];
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

+ (void)VC_ConfigureCache:(NSUInteger)sizeMB {
  double size = sizeMB <= 0 ? 300 : sizeMB;
  if(maxSizeMB != size) {
    maxSizeMB = size;
    [KTVHTTPCache cacheSetMaxCacheLength:(NSUInteger)(maxSizeMB * 1024 * 1024)];
    [self trimCacheIfNeeded];
  };
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

+ (void)trimCacheIfNeeded {
  NSString *cacheDir = [self VC_CacheDir];
  if (!cacheDir) return;
  
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray *files = [fm contentsOfDirectoryAtPath:cacheDir error:nil];
  
  NSMutableArray *fileInfos = [NSMutableArray array];
  NSUInteger totalSize = 0;
  
  for (NSString *file in files) {
    NSString *path = [cacheDir stringByAppendingPathComponent:file];
    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
    if (!attrs) continue;
    
    NSUInteger size = [attrs fileSize];
    NSDate *date = [attrs fileModificationDate] ?: [NSDate date];
    
    totalSize += size;
    [fileInfos addObject:@{ @"path": path, @"size": @(size), @"date": date }];
  }
  
  NSUInteger maxBytes = (NSUInteger)(maxSizeMB * 1024 * 1024);
  if (totalSize <= maxBytes) return;
  
  [fileInfos sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]]];
  
  for (NSDictionary *info in fileInfos) {
    if (totalSize <= maxBytes) break;
    NSString *path = info[@"path"];
    NSUInteger size = [info[@"size"] unsignedIntegerValue];
    [fm removeItemAtPath:path error:nil];
    totalSize -= size;
  }
}

+ (NSURL *)proxyURLWithOriginalURL:(NSURL *)url {
  NSURL *proxyURL = [KTVHTTPCache proxyURLWithOriginalURL:url];
  return proxyURL ?: url;
}
@end
