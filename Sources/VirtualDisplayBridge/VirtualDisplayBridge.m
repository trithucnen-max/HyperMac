#import "VirtualDisplayBridge.h"
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

@class CGVirtualDisplayDescriptor;
@class CGVirtualDisplaySettings;
@class CGVirtualDisplayMode;

@interface CGVirtualDisplayMode : NSObject
- (instancetype)initWithWidth:(NSUInteger)arg1 height:(NSUInteger)arg2 refreshRate:(CGFloat)arg3;
@end

@interface CGVirtualDisplaySettings : NSObject
@property(nonatomic) unsigned int hiDPI;
@property(retain, nonatomic) NSArray<CGVirtualDisplayMode *> *modes;
- (instancetype)init;
@end

@interface CGVirtualDisplay : NSObject
@property(readonly, nonatomic) CGDirectDisplayID displayID;
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)arg1;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)arg1;
@end

@interface CGVirtualDisplayDescriptor : NSObject
@property(retain, nonatomic) dispatch_queue_t queue;
@property(retain, nonatomic) NSString *name;
@property(nonatomic) unsigned int maxPixelsHigh;
@property(nonatomic) unsigned int maxPixelsWide;
@property(nonatomic) CGSize sizeInMillimeters;
@property(nonatomic) unsigned int serialNum;
@property(nonatomic) unsigned int productID;
@property(nonatomic) unsigned int vendorID;
@property(copy, nonatomic) void (^terminationHandler)(id, CGVirtualDisplay*);
- (void)setDispatchQueue:(dispatch_queue_t)arg1;
@end

@implementation VirtualDisplayBridge {
    CGVirtualDisplay *_display;
}

+ (instancetype)shared {
    static VirtualDisplayBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[VirtualDisplayBridge alloc] init];
    });
    return instance;
}

- (uint32_t)createDisplayWithName:(NSString *)name
                            width:(NSUInteger)width
                           height:(NSUInteger)height
                      refreshRate:(double)refreshRate
                            hiDPI:(BOOL)hiDPI {
    if (_display != nil) {
        [self destroyDisplay];
    }

    Class descClass = NSClassFromString(@"CGVirtualDisplayDescriptor");
    Class dispClass = NSClassFromString(@"CGVirtualDisplay");
    Class modeClass = NSClassFromString(@"CGVirtualDisplayMode");
    Class setClass = NSClassFromString(@"CGVirtualDisplaySettings");

    if (!descClass || !dispClass || !modeClass || !setClass) {
        return 0;
    }

    CGVirtualDisplayDescriptor *desc = [descClass new];
    [desc setDispatchQueue:dispatch_get_main_queue()];
    desc.name = name ?: @"HyperMac Virtual Display";
    desc.maxPixelsWide = (unsigned int)MAX(3840, width);
    desc.maxPixelsHigh = (unsigned int)MAX(2160, height);
    desc.sizeInMillimeters = CGSizeMake(531, 298);
    desc.vendorID = 0x1234;
    desc.productID = 0x5678;
    desc.serialNum = 0x0001;

    __weak typeof(self) weakSelf = self;
    desc.terminationHandler = ^(id a, CGVirtualDisplay *disp) {
        dispatch_async(dispatch_get_main_queue(), ^{
            VirtualDisplayBridge *strongSelf = weakSelf;
            if (strongSelf && strongSelf->_display == disp) {
                strongSelf->_display = nil;
            }
        });
    };

    CGVirtualDisplay *display = [[dispClass alloc] initWithDescriptor:desc];
    if (!display) {
        return 0;
    }

    CGVirtualDisplayMode *mode = [[modeClass alloc] initWithWidth:width height:height refreshRate:refreshRate];
    CGVirtualDisplaySettings *settings = [setClass new];
    settings.hiDPI = hiDPI ? 1 : 0;
    settings.modes = @[mode];

    [display applySettings:settings];

    _display = display;
    return display.displayID;
}

- (void)destroyDisplay {
    if (_display != nil) {
        _display = nil;
    }
}

- (BOOL)isActive {
    return _display != nil;
}

- (uint32_t)displayID {
    return _display ? _display.displayID : 0;
}

@end
