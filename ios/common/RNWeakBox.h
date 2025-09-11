//
//  RNWeakBox.h
//  ShareVideo
//
//  Created by Sang Le vinh on 9/5/25.
//

@interface RNWeakBox : NSObject
@property (nonatomic, weak) id obj;
+ (instancetype)box:(id)obj;
@end
