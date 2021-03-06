//
//  DNRequestFacebookManager.h
//  Ding
//
//  Created by Mark Miyashita on 4/6/14.
//  Copyright (c) 2014 Mark Miyashita. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BlocksTypedefs.h"

@interface DNRequestFacebookManager : NSObject

- (void)requestGraphMeWithCompletion:(CompletionBlock)completion;
- (void)requestGraphFriendsWithCompletion:(CompletionBlock)completion;

@end
