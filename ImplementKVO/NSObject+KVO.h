//
//  NSObject+KVO.h
//  ImplementKVO
//
//  Created by Peng Gu on 2/26/15.
//  Copyright (c) 2015 Peng Gu. All rights reserved.
//
/**
 完善者:黄芝标
 在Glow团队demo的基础上增加了变量和KayPath的KVO支持
 */
#import <Foundation/Foundation.h>

typedef void(^PGObservingBlock)(id observedObject, NSString *observedKey, id oldValue, id newValue);

@interface NSObject (KVO)

- (void)PG_addObserver:(NSObject *)observer
                forKeyPath:(NSString *)keyPath
             withBlock:(PGObservingBlock)block;

- (void)PG_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;

@end
