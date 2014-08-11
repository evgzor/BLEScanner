//
//  DetailViewController.h
//  BLEScanner
//
//  Created by Evgeny Zorin on 11/08/14.
//  Copyright (c) 2014 Evgeny Zorin. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) id detailItem;

@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@end
