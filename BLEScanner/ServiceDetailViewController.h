//
//  DetailViewController.h
//  BLEScanner
//
//  Created by Evgeny Zorin on 11/08/14.
//  Copyright (c) 2014 Evgeny Zorin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLEDeviceCentralManager.h"

@interface ServiceDetailViewController : UITableViewController <UISplitViewControllerDelegate, BLEDataChange>

@property(strong) DeviceData* device;

@end
