//
// Copyright (c) 2021 Adyen N.V.
//
// This file is open source and available under the MIT license. See the LICENSE file for more info.
//


#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTViewManager.h>

@interface RCT_EXTERN_MODULE(AdyenTerminal, NSObject)

RCT_EXTERN_METHOD(startDiscovery)
RCT_EXTERN_METHOD(stopDiscovery)

RCT_EXTERN_METHOD(connectTo:(NSDictionary *)device)
RCT_EXTERN_METHOD(disconnect)

RCT_EXTERN_METHOD(startFirmwareUpdate)

RCT_EXTERN_METHOD(pay:(NSNumber *)type
                  requestData:(NSString *)requestData)

RCT_EXTERN_METHOD(setSdkData:(NSString *)callbackId value:(NSString *)value)

@end
