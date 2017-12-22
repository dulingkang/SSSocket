//
//  SSSocket.m
//  Pods-SSSocket_Example
//
//  Created by Shawn on 2017/12/15.
//

#import "SSSocket.h"
#import <SystemConfiguration/SCNetworkReachability.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <UIKit/UIKit.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
#import "SSRunLoop.h"

@implementation SSSocket {
    NSString *_ip;
    int _port;
    SSRunLoop *_runLoop;
    BOOL _isConnected;
    CFSocketRef _socket;
    CFDataRef _address;
    SCNetworkReachabilityRef _reachability;
    NSLock *_lock;
}

#pragma mark - c static function
static void reachabilityCallback(SCNetworkReachabilityRef target, SCNetworkConnectionFlags flags, void* info) {
    SSSocket *s = (__bridge SSSocket*)info;
    if (!s) return;
    [s __releaseSocket];
    [s __processDisconnected];
}

static void socketProcesser(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    SSSocket *s = (__bridge SSSocket*)info;
    if (s == nil) return;
    
    switch (type) {
        case kCFSocketDataCallBack:
            if (CFDataGetLength(data) != 0) {
                NSData *dat = [[NSData alloc] initWithBytes:CFDataGetBytePtr(data) length:CFDataGetLength(data)];
                [s __processRead:dat];
            }
            else
                [s __processDisconnected];
            break;
        default:
            break;
    }
}

#pragma mark - init method
- (instancetype)initIP:(NSString *)ip withPort:(int)port withRunLoop:(SSRunLoop *)runLoop {
    if (self = [super init]) {
        _ip = ip;
        _port = port;
        _runLoop = runLoop;
        _isConnected = NO;
        [self __initAddress];
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (instancetype)initAddress:(NSString*)address withRunLoop:(SSRunLoop *)runLoop {
    NSArray *temp = [address componentsSeparatedByString:@":"];
    NSAssert((temp != nil && [temp count] == 2), [@"Illegal argument: address, " stringByAppendingString:address]);
    NSString *ip = [temp objectAtIndex:0];
    ip = [self __getIPWithHostName:ip];
    NSString *port = [temp objectAtIndex:1];
    return [self initIP:ip withPort:[port intValue] withRunLoop:runLoop];
}

#pragma mark - pulbic method
- (BOOL)isConnected {
    return _isConnected;
}

- (void)connect {
    [self performSelector:@selector(__innerConnect) onThread:[_runLoop getThread] withObject:nil waitUntilDone:NO];
}

- (void)disconnect {
    if(_socket) CFSocketInvalidate(_socket);
    if (!_isConnected) return;
    _isConnected = NO;
    [self __releaseSocket];
    [self __releaseReach];
}

- (BOOL)send:(NSData*)data {
    if (!_socket) return NO;
    CFDataRef Data = CFDataCreate(nil, (const UInt8*)[data bytes], [data length]);
    CFSocketError ret = CFSocketSendData(_socket, nil, Data, 10);
    CFRelease(Data);
    return ret == kCFSocketSuccess;
}

#pragma mark - private method
- (void)__initAddress {
    struct sockaddr_in addr4;
    memset(&addr4, 0, sizeof(addr4));
    addr4.sin_len = sizeof(addr4);
    addr4.sin_family = AF_INET;
    addr4.sin_port = htons(_port);
    addr4.sin_addr.s_addr = inet_addr([_ip UTF8String]);
    _address = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&addr4, sizeof(addr4));
}

- (NSString *)__getIPWithHostName:(const NSString *)hostName {
    const char *hostN= [hostName UTF8String];
    struct hostent* phot;
    
    @try {
        phot = gethostbyname(hostN);
        
    }
    @catch (NSException *exception) {
        return nil;
    }
    
    struct in_addr ip_addr;
    if(phot!=NULL){
        memcpy(&ip_addr, phot->h_addr_list[0], 4);
    } else {
        return @"";
    }
    char ip[20] = {0};
    inet_ntop(AF_INET, &ip_addr, ip, sizeof(ip));
    
    NSString* strIPAddress = [NSString stringWithUTF8String:ip];
    return strIPAddress;
}

- (void)__innerConnect {
    [self __releaseReach];
    [self __initReach];
    [self __releaseSocket];
    [self __initSocket];
    CFSocketError error = CFSocketConnectToAddress(_socket, _address, 5);
    switch (error) {
        case kCFSocketSuccess:
            [self __processConnect];
            break;
        case kCFSocketTimeout:
        case kCFSocketError:
        default:{
            [self __releaseSocket];
            [self __releaseReach];
            [self __processDisconnected];
            break;
            
        }
    }
}

- (void)__releaseReach {
    [_lock lock];
    if (_reachability) return;
    SCNetworkReachabilitySetCallback(_reachability, nil, nil);
    CFRelease(_reachability);
    _reachability = nil;
    [_lock unlock];
}

- (void)__initReach {
    struct sockaddr_in reachAddress;
    bzero(&reachAddress, sizeof(reachAddress));
    reachAddress.sin_len = sizeof(reachAddress);
    reachAddress.sin_family = AF_INET;
    reachAddress.sin_addr.s_addr = inet_addr([_ip UTF8String]);
    
    SCNetworkReachabilityContext reachContent = {0, (__bridge void * _Nullable)(self), nil, nil, nil};
    _reachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&reachAddress);
    SCNetworkReachabilitySetCallback(_reachability, reachabilityCallback, &reachContent) && SCNetworkReachabilityScheduleWithRunLoop(_reachability, [_runLoop getCFRunLoop], kCFRunLoopDefaultMode);
}

- (void)__releaseSocket {
    [_lock lock];
    if (!_socket) return;
    CFSocketDisableCallBacks(_socket, kCFSocketDataCallBack);
    CFRelease(_socket);
    _socket = nil;
    [_lock unlock];
}

- (void)__initSocket {
    CFSocketContext sockContent = {0, (__bridge void *)(self), nil, nil, nil};
    _socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketDataCallBack, socketProcesser, &sockContent);
    CFSocketSetSocketFlags(_socket, (CFSocketGetSocketFlags(_socket) & ~kCFSocketAutomaticallyReenableReadCallBack & ~kCFSocketAutomaticallyReenableWriteCallBack) | kCFSocketAutomaticallyReenableDataCallBack);
    
    CFRunLoopSourceRef sourceLoop = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0);
    CFRunLoopAddSource([_runLoop getCFRunLoop], sourceLoop, kCFRunLoopDefaultMode);
    CFRelease(sourceLoop);
}

- (void)__processDisconnected {
    _isConnected = NO;
    [self.delegate onDisconnected];
}

- (void)__processConnect {
    CFDataRef lData = CFSocketCopyAddress(_socket);
    CFDataRef rData = CFSocketCopyPeerAddress(_socket);
    if (lData != nil && rData != nil) {
        struct sockaddr_in local;
        memcpy(&local, CFDataGetBytePtr(lData), CFDataGetLength(lData));
        
        struct sockaddr_in remote;
        memcpy(&remote, CFDataGetBytePtr(rData), CFDataGetLength(rData));
        
        NSLog(@"socket address:%@", [NSString stringWithFormat:@"/%s:%d - /%s:%d", inet_ntoa(local.sin_addr), ntohs(local.sin_port), inet_ntoa(remote.sin_addr), ntohs(remote.sin_port)]);
    }
    if (lData)
        CFRelease(lData);
    if (rData)
        CFRelease(rData);
    
    _isConnected = YES;
    [self.delegate onConnected];
}

- (void)__processRead:(NSData *)data {
    if ([self.delegate respondsToSelector:@selector(onDataReceived:)]) {
        [self.delegate onDataReceived:data];
    }
}
@end
