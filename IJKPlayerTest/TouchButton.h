//
//  TouchButton.h
//  IJKPlayerTest
//
//  Created by Myron on 2020/10/8.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TouchButtonDelegate <NSObject>

/**
 * 开始触摸
 */
- (void)touchesBeganWithPoint:(CGPoint)point;

/**
 * 结束触摸
 */
- (void)touchesEndWithPoint:(CGPoint)point;

/**
 * 移动手指
 */
- (void)touchesMoveWithPoint:(CGPoint)point;

@end

@interface TouchButton : UIButton

/**
 * 传递点击事件的代理
 */
@property (weak, nonatomic) id <TouchButtonDelegate> touchDelegate;

@end

NS_ASSUME_NONNULL_END
