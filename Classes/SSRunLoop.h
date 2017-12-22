//
//  SSRunLoop.h
//  Pods-SSSocket_Example
//
//  Created by Shawn on 2017/12/22.
//

#import <Foundation/Foundation.h>

@interface SSRunLoop : NSObject

- (NSRunLoop *)getNSRunLoop;
- (CFRunLoopRef)getCFRunLoop;
- (void)closeRunLoop;
- (NSThread *)getThread;
@end
