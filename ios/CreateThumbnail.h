
#ifdef RCT_NEW_ARCH_ENABLED
#import "RNCreateThumbnailSpec.h"

@interface CreateThumbnail : NSObject <NativeCreateThumbnailSpec>
#else
#import <React/RCTBridgeModule.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

@interface CreateThumbnail : NSObject <RCTBridgeModule>
#endif

@end
