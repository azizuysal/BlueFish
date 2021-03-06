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

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@class BFPeripheral;

@protocol BFCentralManagerDelegate <NSObject>

- (void)didDisconnectPeripheral:(BFPeripheral *)peripheral error:(NSError *)error;
- (void)didTurnOffBluetooth;

@end

/**
 * SDK class that manages discovery, connection and disconnection to peripherals.
 * NOTE: All calls of the completion blocks are done in the main thread
 */

@interface BFCentralManager : NSObject <CBCentralManagerDelegate>

/*
 * The current connected peripheral
 */
@property (strong, nonatomic, readonly) BFPeripheral *connectedPeripheral;

/**
 *  The delegate which will receive updates on peripheral disconnection
 */
@property (weak, nonatomic, readwrite) id <BFCentralManagerDelegate> delegate;

#pragma mark - Scan methods

/**
 *  Launch scan of nearby devices.
 */
- (void)startScanningWithUpdateBlock:(void (^)(BFPeripheral *peripheral, NSError *error))updateBlock;

/**
 *  Launch scan for nearby devices that expose the services passed as parameter
 *
 *  @param services    An array of CBUUID indicating the services to scan for
 *  @param updateBLock A block to be executed each time there's an update in the devices discovery
 */
- (void)startScanningWithServices:(NSArray <CBUUID *> *)services updateBlock:(void (^)(BFPeripheral *peripheral, NSError *error))updateBlock;

/**
 *  Stop the scan of devices
 */
- (void)stopScanning;

#pragma mark - Connection methods

/**
 *  Start connection on a given peripheral. THIS METHOD DOES NOT TIME OUT
 *
 *  @param peripheral      The peripheral to connect to
 *  @param completionBlock The block called on completion with an error, if present, passed as parameter
 */
- (void)connectToPeripheral:(BFPeripheral *)peripheral completionBlock:(void (^)(NSError *error))completionBlock;

/**
 *  Disconnect from a connected peripheral
 *
 *  @param peripheral The peripheral to which disconnect to
 */
- (void)disconnectPeripheral:(BFPeripheral *)peripheral;

/**
 *  Cancel all current pending connection with peripheral
 *
 *  @param peripheral The peripheral on which interrupt all connections
 */
- (void)cancelConnectionToPeripheral:(BFPeripheral *)peripheral;

#pragma mark - Device retrieval

/**
 *  Retrieve peripheral cached in the CoreBluetooth stack. To be used before scanning for nearby peripherals.
 *
 *  @param ID              The ID of the peripheral to search for
 *  @param completionBlock A block to be executed on completion, with the the peripheral if existing or an error.
 */
- (BFPeripheral *)retrievePeripheralWithID:(NSString *)ID;

@end
