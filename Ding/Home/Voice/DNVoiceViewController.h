//
//  DNVoiceViewController.h
//  Ding
//
//  Created by Melissa on 4/5/14.
//  Copyright (c) 2014 Mark Miyashita. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <CoreData/CoreData.h>

@class DNHomeNavigationController;

@interface DNVoiceViewController : UITableViewController <NSFetchedResultsControllerDelegate> {
    DNHomeNavigationController * homeNavigationController;
}

@property (nonatomic, retain) DNHomeNavigationController *homeNavigationController;
@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain) NSFetchedResultsController *fetchedResultsController;

@end
