//
//  RCTContainerPoster.h
//  shareelement
//
//  Created by Sang Le vinh on 9/26/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Một UIView trống, chuyên làm container cho playerLayer và posterView.
/// Không tự tạo AVPlayerLayer, chỉ resize subviews/sublayers khi layout.
@interface RCTContainerPoster : UIView
@end

NS_ASSUME_NONNULL_END
