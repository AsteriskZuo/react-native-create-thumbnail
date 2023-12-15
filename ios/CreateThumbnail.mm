#import "CreateThumbnail.h"

@implementation CreateThumbnail
RCT_EXPORT_MODULE()

// Example method
// See // https://reactnative.dev/docs/native-modules-ios
RCT_REMAP_METHOD(multiply, multiplyWithA
                 : (double)a withB
                 : (double)b withResolver
                 : (RCTPromiseResolveBlock)resolve withRejecter
                 : (RCTPromiseRejectBlock)reject) {
  NSNumber *result = @(a * b);

  resolve(result);
}

RCT_EXPORT_METHOD(create
                  : (NSDictionary *)config findEventsWithResolver
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject) {

  PHAuthorizationStatus localStatus = [self permissionStatus];
  if (localStatus != PHAuthorizationStatusAuthorized) {
    [self requestPermission:^(PHAuthorizationStatus permission) {
      if (localStatus != PHAuthorizationStatusAuthorized) {
        return;
      }
    }];
  }
  if (localStatus != PHAuthorizationStatusAuthorized) {
    reject(@"author error", @"no photo library permission", nil);
    return;
  }

  NSString *url = (NSString *)[config objectForKey:@"url"] ?: @"";
  int timeStamp = [[config objectForKey:@"timeStamp"] intValue] ?: 0;
  NSString *format = (NSString *)[config objectForKey:@"format"] ?: @"jpeg";
  int dirSize = [[config objectForKey:@"dirSize"] intValue] ?: 100;
  NSString *cacheName = (NSString *)[config objectForKey:@"cacheName"];
  NSDictionary *headers = config[@"headers"] ?: @{};

  unsigned long long cacheDirSize = dirSize * 1024 * 1024;

  @try {
    // Prepare cache folder
    NSString *tempDirectory = [NSSearchPathForDirectoriesInDomains(
        NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    tempDirectory = [tempDirectory stringByAppendingString:@"/thumbnails/"];
    // Create thumbnail directory if not exists
    [[NSFileManager defaultManager] createDirectoryAtPath:tempDirectory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    NSString *fileName =
        [NSString stringWithFormat:@"thumb-%@.%@",
                                   cacheName
                                       ?: [[NSProcessInfo processInfo]
                                              globallyUniqueString],
                                   format];
    NSString *fullPath =
        [tempDirectory stringByAppendingPathComponent:fileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
      NSData *imageData =
          [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:fullPath]];
      UIImage *thumbnail = [UIImage imageWithData:imageData];
      resolve(@{
        @"path" : fullPath,
        @"size" : [NSNumber numberWithFloat:imageData.length],
        @"mime" : [NSString stringWithFormat:@"image/%@", format],
        @"width" : [NSNumber numberWithFloat:thumbnail.size.width],
        @"height" : [NSNumber numberWithFloat:thumbnail.size.height]
      });
      return;
    }

    NSURL *vidURL = nil;
    NSString *url_ = [url lowercaseString];

    if ([url_ hasPrefix:@"http://"] || [url_ hasPrefix:@"https://"] ||
        [url_ hasPrefix:@"file://"]) {
      vidURL = [NSURL URLWithString:url];
    } else {
      // Consider it's file url path
      vidURL = [NSURL fileURLWithPath:url];
    }

    AVURLAsset *asset = [[AVURLAsset alloc]
        initWithURL:vidURL
            options:@{@"AVURLAssetHTTPHeaderFieldsKey" : headers}];
    [self generateThumbImage:asset
        atTime:timeStamp
        completion:^(UIImage *thumbnail) {
          // Clean directory
          unsigned long long size = [self sizeOfFolderAtPath:tempDirectory];
          if (size >= cacheDirSize) {
            [self cleanDir:tempDirectory forSpace:cacheDirSize / 2];
          }

          // Generate thumbnail
          NSData *data = nil;
          if ([format isEqual:@"png"]) {
            data = UIImagePNGRepresentation(thumbnail);
          } else {
            data = UIImageJPEGRepresentation(thumbnail, 1.0);
          }

          NSFileManager *fileManager = [NSFileManager defaultManager];
          [fileManager createFileAtPath:fullPath contents:data attributes:nil];
          resolve(@{
            @"path" : fullPath,
            @"size" : [NSNumber numberWithFloat:data.length],
            @"mime" : [NSString stringWithFormat:@"image/%@", format],
            @"width" : [NSNumber numberWithFloat:thumbnail.size.width],
            @"height" : [NSNumber numberWithFloat:thumbnail.size.height]
          });
        }
        failure:^(NSError *error) {
          reject(error.domain, error.description, nil);
        }];

  } @catch (NSException *e) {
    reject(e.name, e.reason, nil);
  }
}

- (unsigned long long)sizeOfFolderAtPath:(NSString *)path {
  NSArray *files =
      [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:path error:nil];
  NSEnumerator *enumerator = [files objectEnumerator];
  NSString *fileName;
  unsigned long long size = 0;
  while (fileName = [enumerator nextObject]) {
    size += [[[NSFileManager defaultManager]
        attributesOfItemAtPath:[path stringByAppendingPathComponent:fileName]
                         error:nil] fileSize];
  }
  return size;
}

- (void)cleanDir:(NSString *)path forSpace:(unsigned long long)size {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSError *error = nil;
  unsigned long long deletedSize = 0;
  for (NSString *file in [fm contentsOfDirectoryAtPath:path error:&error]) {
    unsigned long long fileSize = [[[NSFileManager defaultManager]
        attributesOfItemAtPath:[path stringByAppendingPathComponent:file]
                         error:nil] fileSize];
    BOOL success =
        [fm removeItemAtPath:[NSString stringWithFormat:@"%@%@", path, file]
                       error:&error];
    if (success) {
      deletedSize += fileSize;
    }
    if (deletedSize >= size) {
      break;
    }
  }
  return;
}

- (void)generateThumbImage:(AVURLAsset *)asset
                    atTime:(int)timeStamp
                completion:(void (^)(UIImage *thumbnail))completion
                   failure:(void (^)(NSError *error))failure {
  AVAssetImageGenerator *generator =
      [[AVAssetImageGenerator alloc] initWithAsset:asset];
  generator.appliesPreferredTrackTransform = YES;
  generator.maximumSize = CGSizeMake(512, 512);
  generator.requestedTimeToleranceBefore = CMTimeMake(0, 1000);
  generator.requestedTimeToleranceAfter = CMTimeMake(0, 1000);
  CMTime time = CMTimeMake(timeStamp, 1000);
  AVAssetImageGeneratorCompletionHandler handler =
      ^(CMTime timeRequested, CGImageRef image, CMTime timeActual,
        AVAssetImageGeneratorResult result, NSError *error) {
        if (result == AVAssetImageGeneratorSucceeded) {
          UIImage *thumbnail = [UIImage imageWithCGImage:image];
          completion(thumbnail);
        } else {
          failure(error);
        }
      };
  [generator generateCGImagesAsynchronouslyForTimes:
                 [NSArray arrayWithObject:[NSValue valueWithCMTime:time]]
                                  completionHandler:handler];
}

- (PHAuthorizationStatus)permissionStatus {
  if (@available(iOS 14, *)) {
    return [PHPhotoLibrary
        authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
  } else {
    // Fallback on earlier versions
    return [PHPhotoLibrary authorizationStatus];
  }
}

- (void)requestPermission:(void (^)(PHAuthorizationStatus permission))onResult {
  [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
    dispatch_async(dispatch_get_main_queue(), ^{
      onResult(status);
      //      if (status == PHAuthorizationStatusAuthorized) {
      //        // Permissions have been obtained.
      //      } else if (status == PHAuthorizationStatusDenied) {
      //        // The user has explicitly denied application access to this
      //        photo data
      //      } else if (status == PHAuthorizationStatusRestricted) {
      //        // This application does not have authorized access to photo
      //        data. It
      //        // could be parental control
      //      }
    });
  }];
}

// Don't compile this code when we build for the old architecture.
#ifdef RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeCreateThumbnailSpecJSI>(
      params);
}
#endif

@end
