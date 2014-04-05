//
//  DNAppDelegate.m
//  Ding
//
//  Created by Mark Miyashita on 4/5/14.
//  Copyright (c) 2014 Mark Miyashita. All rights reserved.
//

#import "DNAppDelegate.h"

#import "DNSettingsNavigationController.h"
#import "DNFriendsNavigationController.h"
#import "DNHomeNavigationController.h"

#import "DNHomeViewController.h"

#import "MMDrawerController.h"

@implementation DNAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [self setWindow:[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]]];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
        UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
        splitViewController.delegate = (id)navigationController.topViewController;
        self.window.rootViewController = splitViewController;
    } else {
        DNHomeViewController *homeViewController = [[DNHomeViewController alloc] init];
        
        DNSettingsNavigationController *settingsNavigationController = [[DNSettingsNavigationController alloc] init];
        DNHomeNavigationController *homeNavigationController = [[DNHomeNavigationController alloc] initWithRootViewController:homeViewController];
        DNFriendsNavigationController *friendsNavigationController = [[DNFriendsNavigationController alloc] init];
        
        MMDrawerController * drawerController = [[MMDrawerController alloc] initWithCenterViewController:homeNavigationController leftDrawerViewController:settingsNavigationController rightDrawerViewController:friendsNavigationController];
        
        [self.window setRootViewController:drawerController];
    }

    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application {
  // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
  // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
  // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
  // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
  // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
