//
//  UIView+NavTitleCache.h
//  ShareVideo
//
//  Created by Sang Lv on 30/8/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (NavTitleCache)

#ifdef DEBUG
#define RCTLog(selfRef, fmt, ...) do { \
    NSString *navTitle = [(selfRef) rn_currentNavTitle]; \
    NSLog((@"[%@][RCTShare][%@:%d][%@] " fmt), \
           [[NSDate date] descriptionWithLocale:nil], \
           [[NSString stringWithUTF8String:__FILE__] lastPathComponent], \
           __LINE__, \
           navTitle, \
           ##__VA_ARGS__); \
} while(0)
#else
#define RCTLog(selfRef, fmt, ...)
#endif

/// Cache lại nav title để dùng khi view mất window
@property (nonatomic, copy, nullable) NSString *rn_cachedNavTitle;

/// Cập nhật cache từ nearest VC (nếu có)
- (void)rn_updateCachedNavTitle;

/// Lấy nav title hiện tại (ưu tiên cached)
- (NSString *)rn_currentNavTitle;

@end

NS_ASSUME_NONNULL_END
