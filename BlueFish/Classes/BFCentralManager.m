//
// Copyright 2016 Mobile Jazz SL
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "BFCentralManager.h"

#import "BFPeripheral.h"
#import "BFPeripheral_Private.h"

#import "NSArray+BlueFish.h"
#import "NSError+BlueFish.h"

#import "BFErrorConstants.h"

@interface BFCentralManager ()

@property (nonatomic, strong, readwrite) CBCentralManager *centralManager;

@property (nonatomic, strong, readwrite) NSMutableArray *internalPeripheralList;
@property (nonatomic, strong, readwrite) NSMutableDictionary <CBPeripheral *, BFPeripheral *> *peripheralList;

@property (nonatomic, strong, readwrite) CBPeripheral *connectingPeripheral;
@property (strong, nonatomic, readwrite) BFPeripheral *connectedPeripheral;

@property (nonatomic, strong, readwrite) NSArray *servicesToScan;
@property (nonatomic, assign, readwrite) BOOL scanningEnabled;

@property (nonatomic, copy, readwrite) void (^ BFDeviceScanBlock)(BFPeripheral *peripheral, NSError *error);
@property (nonatomic, copy, readwrite) void (^ BFPeripheralConnectionBlock)(NSError *error);

@end

@implementation BFCentralManager

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        dispatch_queue_t bluetoothQueue = dispatch_queue_create("com.mobilejazz.bluetooth", DISPATCH_QUEUE_SERIAL);

        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:bluetoothQueue];

        _internalPeripheralList = [NSMutableArray array];
        _peripheralList = [[NSMutableDictionary alloc] init];
    }

    return self;
}

#pragma mark - Public methods

#pragma mark Scan methods

- (void)startScanningWithUpdateBlock:(void (^)(BFPeripheral *peripheral, NSError *error))updateBlock
{
    [self startScanningWithServices:nil updateBlock:updateBlock];
}

- (void)startScanningWithServices:(NSArray <CBUUID *> *)services updateBlock:(void (^)(BFPeripheral *peripheral, NSError *error))updateBlock
{
    self.BFDeviceScanBlock = updateBlock;
    self.servicesToScan = services;

    [self bf_startScanning];
}

- (void)stopScanning
{
    self.BFDeviceScanBlock = nil;
    [_centralManager stopScan];
}

#pragma mark - Retrieve peripheral

- (BFPeripheral *)retrievePeripheralWithID:(NSString *)ID
{
    CBPeripheral *peripheral = [_internalPeripheralList bf_peripheralWithID:ID];

    if (peripheral)
    {
        return _peripheralList[peripheral];
    }

    NSUUID *deviceID = [[NSUUID alloc] initWithUUIDString:ID];
    NSArray *peripherals = [_centralManager retrievePeripheralsWithIdentifiers:@[deviceID]];

    if ([peripherals firstObject])
    {
        peripheral = [peripherals firstObject];
        _peripheralList[peripheral] = [[BFPeripheral alloc] initWithPeripheral:peripheral];
        return _peripheralList[peripheral];
    }

    return nil;
}

#pragma mark - Connection

- (void)connectToPeripheral:(BFPeripheral *)peripheral completionBlock:(void (^)(NSError *error))completionBlock
{
    if (peripheral.BTPeripheral.state == CBPeripheralStateConnected)
    {
        completionBlock(nil);
        return;
    }

    self.connectingPeripheral = peripheral.BTPeripheral;
    self.BFPeripheralConnectionBlock = completionBlock;

    [_centralManager connectPeripheral:_connectingPeripheral options:nil];
}

- (void)disconnectPeripheral:(BFPeripheral *)peripheral
{
    [self cancelConnectionToPeripheral:peripheral];
}

- (void)cancelConnectionToPeripheral:(BFPeripheral *)peripheral
{
    if (!peripheral)
    {
        return;
    }

    self.BFPeripheralConnectionBlock = nil;
    self.connectingPeripheral = nil;

    [_centralManager cancelPeripheralConnection:peripheral.BTPeripheral];
}

#pragma mark - Private methods

- (void)bf_startScanning
{
    if (_centralManager.state == CBCentralManagerStatePoweredOn)
    {
        [_centralManager scanForPeripheralsWithServices:_servicesToScan options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @NO}];
    }
    else
    {
        self.scanningEnabled = YES;
    }
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state)
    {
        case CBCentralManagerStateUnsupported:
            if (_BFDeviceScanBlock)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    _BFDeviceScanBlock(nil, [NSError bf_createErrorWithDomain:BFErrorDomain code:BFErrorCodeDeviceNotSupported description:nil]);
                });
            }
            break;
        case CBCentralManagerStateUnauthorized:
            if (_BFDeviceScanBlock)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    _BFDeviceScanBlock(nil, [NSError bf_createErrorWithDomain:BFErrorDomain code:BFErrorCodeBluetoothNotAuthorized description:nil]);
                });
            }
            break;
        case CBCentralManagerStatePoweredOff:
            if ([_delegate respondsToSelector:@selector(didTurnOffBluetooth)])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_delegate didTurnOffBluetooth];
                });

            }
            break;
        case CBCentralManagerStatePoweredOn:
            if (_scanningEnabled)
            {
                [self bf_startScanning];
                self.scanningEnabled = NO;
            }
            break;
        default:
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    if (![self.internalPeripheralList containsObject:peripheral])
    {
        [self.internalPeripheralList addObject:peripheral];
        BFPeripheral *bfPeripheral = [[BFPeripheral alloc] initWithPeripheral:peripheral];
        self.peripheralList[peripheral] = bfPeripheral;
    }
    __weak typeof(self) weakSelf = self;
    if (_BFDeviceScanBlock)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.BFDeviceScanBlock(_peripheralList[peripheral], nil);
        });
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    if ([self.connectingPeripheral isEqual:peripheral])
    {
        self.connectingPeripheral = nil;
        self.connectedPeripheral = _peripheralList[peripheral];

        if (_BFPeripheralConnectionBlock)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                _BFPeripheralConnectionBlock(nil);
                self.BFPeripheralConnectionBlock = nil;
            });
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Failed to connect to peripheral: %@ error: %@", peripheral.description, error);
    }
    if ([self.connectingPeripheral isEqual:peripheral])
    {
        self.connectingPeripheral = nil;
        self.connectedPeripheral = nil;

        if (_BFPeripheralConnectionBlock)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                _BFPeripheralConnectionBlock(error);
                self.BFPeripheralConnectionBlock = nil;
            });
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Did disconnected peripheral: %@ error:%@", peripheral.description, error.localizedDescription);
    if ([peripheral isEqual:_connectedPeripheral.BTPeripheral])
    {
        self.connectedPeripheral = nil;
        if ([_delegate respondsToSelector:@selector(didDisconnectPeripheral:error:)])
        {
            BFPeripheral *BTperipheral = self.peripheralList[peripheral];
            dispatch_async(dispatch_get_main_queue(), ^{
                [_delegate didDisconnectPeripheral:BTperipheral error:error];
            });
        }
    }
}

@end
