#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VirtualDisplayBridge : NSObject

+ (instancetype)shared;

- (uint32_t)createDisplayWithName:(NSString *)name
                            width:(NSUInteger)width
                           height:(NSUInteger)height
                      refreshRate:(double)refreshRate
                            hiDPI:(BOOL)hiDPI;

- (void)destroyDisplay;

- (BOOL)isActive;
- (uint32_t)displayID;

@end

NS_ASSUME_NONNULL_END
