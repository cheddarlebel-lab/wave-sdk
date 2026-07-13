#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

// Bridges the Swift WaveUnlockModule (RCTEventEmitter) to React Native.
@interface RCT_EXTERN_MODULE(WaveUnlock, RCTEventEmitter)

RCT_EXTERN_METHOD(startUnlock:(NSDictionary *)config)
RCT_EXTERN_METHOD(cancel)

@end
