//
//  BLEDeviceManager.m
//  BLEScanner
//
//  Created by Evgeny Zorin on 11/08/14.
//  Copyright (c) 2014 Evgeny Zorin. All rights reserved.
//

#import "BLEDeviceCentralManager.h"

#import <CoreBluetooth/CoreBluetooth.h>

@interface NSMutableArray(device)

-(BOOL)isContainUUID:(NSString*)name;
-(DeviceData*)getDeviceByUUID:(NSString*)uuid;

@end

@implementation NSMutableArray(device)

-(BOOL)isContainUUID:(NSString*)name
{
   __block BOOL result = NO;
[self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {

    *stop  = result = [[(DeviceData*)obj uuid] isEqualToString:name];
}];
    return result;
}

-(DeviceData*)getDeviceByUUID:(NSString*)uuid
{
    for (DeviceData*obj in self) {
        if ([obj.uuid isEqual:uuid]) {
            return obj;
        }
    }
    return nil;
}

-(id)getServiceByUUID:(NSString*)uuid
{
    for (ServiceData* obj in self) {
        if ([obj.uuid isEqual:uuid]) {
            return obj;
        }
    }
    return nil;
}

-(id)getCharacteristicsByUUID:(NSString*)uuid
{
    for (CBCharacteristic* obj in self) {
        if ([obj.UUID.UUIDString isEqual:uuid]) {
            return obj;
        }
    }
    return nil;
}

@end

@implementation DeviceData


@end

@implementation ServiceData



@end

@interface  BLEDeviceCentralManager() <CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate>

@property (strong, nonatomic) CBCentralManager      *centralManager;
@property (strong, nonatomic) CBPeripheralManager  *peripheralManager;
@property (strong, nonatomic) CBPeripheral          *discoveredPeripheral;
@property (strong, nonatomic) NSMutableData         *data;


@end

@implementation BLEDeviceCentralManager

+ (BLEDeviceCentralManager*)instance
{
    static dispatch_once_t p = 0;
    static BLEDeviceCentralManager *manager = nil;
    
    dispatch_once(&p, ^{
        manager = [[self alloc] init];
    });
    
    return manager;
}

-(BLEDeviceCentralManager*)init
{
    self = [super init];
    
    if (self) {
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
        // And somewhere to store the incoming data
        _data = [[NSMutableData alloc] init];
        _deviceList = [@[] mutableCopy];
    }
    return self;
}

#pragma mark - Peripheral Methods

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    NSLog(@"\nperipheral.state = %d\n", peripheral.state);
}

#pragma mark - Central Methods


/** centralManagerDidUpdateState is a required protocol method.
 *  Usually, you'd check for other states to make sure the current device supports LE, is powered on, etc.
 *  In this instance, we're just using it to wait for CBCentralManagerStatePoweredOn, which indicates
 *  the Central is ready to be used.
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state != CBCentralManagerStatePoweredOn) {
        // In a real app, you'd deal with all the states correctly
        return;
    }
    self.discoveredPeripheral = nil;
    // The state must be CBCentralManagerStatePoweredOn...
    
    // ... so start scanning
    [self scan];
    
}


/** Scan for peripherals - specifically for our service's 128bit CBUUID
 */
- (void)scan
{
    [self.centralManager scanForPeripheralsWithServices:nil
                                                options: nil];
    
    NSLog(@"Scanning started");
}


/** This callback comes whenever a peripheral that is advertising the TRANSFER_SERVICE_UUID is discovered.
 *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
 *  we start the connection process
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    
#if 0
    if([central.applicationState] == UIApplicationStateActive)
        NSLog(@"current app state - active");
    else if ([UIApplication *].applicationState == UIApplicationStateBackground)
        NSLog(@"current app state - background");
    
    {
        NSLog(@"RSSI is %d", RSSI.integerValue);
        // Reject any where the value is above reasonable range
        if (RSSI.integerValue > -15) {
            return;
        }
        
        // Reject if the signal strength is too low to be close enough (Close is around -22dB)
        if (RSSI.integerValue < -35) {
            return;
        }
    }
#endif
    
    /*if (self.discoveredPeripheral != nil) {
        NSLog(@"device detected, but we're already working with a different device");
        // we're already active with another device or are tearing down the previous connection
        return;
    }*/
    
    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    
    
    // Ok, it's in range - have we already seen it?
    if (![self.deviceList isContainUUID:[peripheral.identifier UUIDString]]) {
        
        DeviceData* device = [[DeviceData alloc] init];
        device.deviceName = peripheral.name;
        device.uuid = [peripheral.identifier UUIDString];
        device.serviceList = [@[] mutableCopy];
        
        [self.deviceList addObject:device];
        
        // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
        self.discoveredPeripheral = peripheral;
        
        // And connect
        NSLog(@"Connecting to peripheral %@", peripheral);
        [self.centralManager connectPeripheral:peripheral options:nil];
        [self.delegate updateData];
    }
}


/** If the connection fails for whatever reason, we need to deal with it.
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Failed to connect to %@. (%@)", peripheral, [error localizedDescription]);
    [self cleanup];
}


/** We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral Connected");
    
    // Stop scanning
    [self.centralManager stopScan];
    NSLog(@"Scanning stopped");
    
    // Clear the data that we may already have
    [self.data setLength:0];
    
    // Make sure we get the discovery callbacks
    peripheral.delegate = self;
    
    // Search only for services that match our UUID
    [peripheral discoverServices:nil];
}


/** The Transfer Service was discovered
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        [self cleanup];
        return;
    }
    
    DeviceData* device = [self.deviceList getDeviceByUUID:[peripheral.identifier UUIDString]];
    
    // Discover the characteristic we want...
    
    // Loop through the newly filled peripheral.services array, just in case there's more than one.
    for (CBService *service in peripheral.services) {
        NSString* serviceName  = service.UUID.UUIDString;
        ServiceData* serviceData = [[ServiceData alloc] init];
        serviceData.serviceName = serviceName;
        serviceData.uuid = service.UUID.UUIDString;
        serviceData.characteristics = [@[] mutableCopy];
        NSLog(@"%@",serviceName);
        [device.serviceList addObject:serviceData];
        [peripheral discoverCharacteristics:nil forService:service];
    }
}


/** The Transfer characteristic was discovered.
 *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    // Deal with errors (if any)
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        [self cleanup];
        return;
    }
    DeviceData* device = [self.deviceList getDeviceByUUID:[peripheral.identifier UUIDString]];
    ServiceData* serviceData = [device.serviceList getServiceByUUID:service.UUID.UUIDString];
    // Again, we loop through the array, just in case.
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        // And check if it's the right one
        if (characteristic.UUID) {
            NSLog(@"%@",characteristic.UUID.UUIDString);
            [serviceData.characteristics addObject:characteristic.UUID.UUIDString];
            // If it is, subscribe to it
            //[peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
    [self.delegate updateData];
    // Once this is complete, we just need to wait for the data to come in.
}


/** This callback lets us know more data has arrived via notification on the characteristic
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        return;
    }
    
    NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    
    // Have we got everything we need?
    if ([stringFromData isEqualToString:@"EOM"]) {
        
        // We have, so show the data,
        /*[self.textview setText:[[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding]];*/
        
        // Cancel our subscription to the characteristic
        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
        
        // and disconnect from the peripehral
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
    
    // Otherwise, just add the data on to what we already have
    [self.data appendData:characteristic.value];
    
    // Log it
    NSLog(@"Received: %@", stringFromData);
}


/** The peripheral letting us know whether our subscribe/unsubscribe happened or not
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error changing notification state: %@", error.localizedDescription);
    }
    
    // Exit if it's not the transfer characteristic
    if (YES/*![characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]*/) {
        return;
    }
    
    // Notification has started
    if (characteristic.isNotifying) {
        NSLog(@"Notification began on %@", characteristic);
    }
    
    // Notification has stopped
    else {
        // so disconnect from the peripheral
        NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}


/** Once the disconnection happens, we need to clean up our local copy of the peripheral
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Peripheral Disconnected");
    self.discoveredPeripheral = nil;
    
    // We're disconnected, so start scanning again
    [self scan];
}


/** Call this when things either go wrong, or you're done with the connection.
 *  This cancels any subscriptions if there are any, or straight disconnects if not.
 *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
 */
- (void)cleanup
{
    // Don't do anything if we're not connected
    if (!(self.discoveredPeripheral.state == CBPeripheralStateConnected)) {
        return;
    }
    
    // See if we are subscribed to a characteristic on the peripheral
    if (self.discoveredPeripheral.services != nil) {
        for (CBService *service in self.discoveredPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if (YES/*[characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]*/) {
                        if (characteristic.isNotifying) {
                            // It is notifying, so unsubscribe
                            [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            
                            // And we're done.
                            return;
                        }
                    }
                }
            }
        }
    }
    
    // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
    [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
}

#pragma mark - Private functions



@end
