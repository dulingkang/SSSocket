//
//  SSSocket.h
//  Pods-SSSocket_Example
//
//  Created by Shawn on 2017/12/15.
//

#import <Foundation/Foundation.h>

@class SSRunLoop;
@protocol SSSocketDelegate<NSObject>
- (void)onConnected;
- (void)onDisconnected;
- (void)onDataReceived:(NSData *)data;
@end

@interface SSSocket : NSObject

@property (nonatomic, weak) id<SSSocketDelegate> delegate;

- (instancetype)initIP:(NSString *)ip withPort:(int)port withRunLoop:(SSRunLoop *)runLoop;
- (instancetype)initAddress:(NSString*)address withRunLoop:(SSRunLoop *)runLoop;
- (BOOL)isConnected;
- (void)connect;
- (void)disconnect;
- (BOOL)send:(NSData*)data;
@end
