//
//  BLEDeviceManager.h
//  BLEScanner
//
//  Created by Evgeny Zorin on 11/08/14.
//  Copyright (c) 2014 Evgeny Zorin. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol BLEDataChange;

@interface ServiceData : NSObject

@property (strong)NSString* serviceName;
@property (strong) NSString* uuid;
@property (strong)NSMutableArray* characteristics;

@end

@interface DeviceData : NSObject

@property (strong) NSString* deviceName;
@property (strong) NSString* uuid;
@property (strong) NSMutableArray* serviceList;

@end

@interface BLEDeviceCentralManager : NSObject

@property (strong) NSMutableArray* deviceList;
@property (weak) id<BLEDataChange> delegate;

+ (BLEDeviceCentralManager*)instance;


@end

@protocol BLEDataChange <NSObject>

-(void)updateData;

@end