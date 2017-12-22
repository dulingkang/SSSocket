//
//  SSRunLoop.m
//  Pods-SSSocket_Example
//
//  Created by Shawn on 2017/12/22.
//

#import "SSRunLoop.h"

@implementation SSRunLoop {
    BOOL _isRunning;
    NSThread *_t;
    NSRunLoop *_runLoop;
    dispatch_semaphore_t _sem;
}

- (id)init {
    self = [super init];
    if (self) {
        _sem = dispatch_semaphore_create(0);
        _isRunning = YES;
        _t = [[NSThread alloc] initWithTarget:self selector:@selector(__threadProc) object:nil];
        [_t start];
        if (!_runLoop) dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
    }
    return self;
}

- (void)dealloc {
    _isRunning = NO;
}

#pragma mark - public method
- (NSRunLoop *)getNSRunLoop {
    return _runLoop;
}

- (CFRunLoopRef)getCFRunLoop {
    return [_runLoop getCFRunLoop];
}

- (NSThread *)getThread {
    return _t;
}

- (void)closeRunLoop {
    _isRunning = NO;
}

#pragma mark - private method
- (void)__threadProc {
    _runLoop = [NSRunLoop currentRunLoop];
    dispatch_semaphore_signal(_sem);
    do {
        [_runLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5]];
        
    } while (_isRunning);
}
@end
