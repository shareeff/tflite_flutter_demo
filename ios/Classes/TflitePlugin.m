#import "TflitePlugin.h"
#import <tflite/tflite-Swift.h>

@implementation TflitePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftTflitePlugin registerWithRegistrar:registrar];
}
@end
