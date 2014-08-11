//
//  MasterViewController.h
//  BLEScanner
//
//  Created by Evgeny Zorin on 11/08/14.
//  Copyright (c) 2014 Evgeny Zorin. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ServiceDetailViewController;

@interface GeneralDeviceListViewController : UITableViewController

@property (strong, nonatomic) ServiceDetailViewController *detailViewController;

@end
