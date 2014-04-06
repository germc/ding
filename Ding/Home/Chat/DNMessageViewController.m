//
//  DNMessageViewController.m
//  Ding
//
//  Created by Melissa on 4/5/14.
//  Copyright (c) 2014 Mark Miyashita. All rights reserved.
//

#import "DNMessageViewController.h"
#import "DNMessage.h"
#import "NSString+Additions.h"

#import "DNAppDelegate.h"

#define CHAT_BACKGROUND_COLOR [UIColor colorWithRed:0.859f green:0.886f blue:0.929f alpha:1.0f]

#define VIEW_WIDTH    self.view.frame.size.width
#define VIEW_HEIGHT    self.view.frame.size.height

#define RESET_CHAT_BAR_HEIGHT    SET_CHAT_BAR_HEIGHT(kChatBarHeight1)
#define EXPAND_CHAT_BAR_HEIGHT    SET_CHAT_BAR_HEIGHT(kChatBarHeight4)
#define    SET_CHAT_BAR_HEIGHT(HEIGHT)\
CGRect chatContentFrame = chatContent.frame;\
chatContentFrame.size.height = VIEW_HEIGHT - HEIGHT;\
[UIView beginAnimations:nil context:NULL];\
[UIView setAnimationDuration:0.1f];\
chatContent.frame = chatContentFrame;\
chatBar.frame = CGRectMake(chatBar.frame.origin.x, chatContentFrame.size.height,\
VIEW_WIDTH, HEIGHT);\
[UIView commitAnimations]

#define BAR_BUTTON(TITLE, SELECTOR) [[UIBarButtonItem alloc] initWithTitle:TITLE\
style:UIBarButtonItemStylePlain target:self action:SELECTOR]

#define ClearConversationButtonIndex 0

// 15 mins between messages before we show the date
#define SECONDS_BETWEEN_MESSAGES        (60*15)

static CGFloat const kSentDateFontSize = 13.0f;
static CGFloat const kMessageFontSize   = 16.0f;   // 15.0f, 14.0f
static CGFloat const kMessageTextWidth  = 180.0f;
static CGFloat const kContentHeightMax  = 84.0f;  // 80.0f, 76.0f
static CGFloat const kChatBarHeight1    = 40.0f;
static CGFloat const kChatBarHeight4    = 94.0f;

@implementation DNMessageViewController

@synthesize chatContent;

@synthesize chatBar;
@synthesize chatInput;
@synthesize previousContentHeight;
@synthesize sendButton;

@synthesize cellMap;

@synthesize fetchedResultsController;
@synthesize managedObjectContext;

- (void)viewDidUnload {
    //self.navigationItem.title = cell.textLabel.text

    self.chatContent = nil;
    
    self.chatBar = nil;
    self.chatInput = nil;
    self.sendButton = nil;
    
    self.cellMap = nil;
    
    self.fetchedResultsController = nil;
    
    // Leave managedObjectContext since it's not recreated in viewDidLoad
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewDidUnload];
}

- (DNAppDelegate *)appDelegate {
    return (DNAppDelegate *)[[UIApplication sharedApplication] delegate];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"DNMessageViewController viewDidLoad");
    self.navigationController.navigationBar.translucent = NO;
    
    self.title = self.conversation.bareJidStr;
    
    // Listen for keyboard.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
    self.view.backgroundColor = CHAT_BACKGROUND_COLOR; // shown during rotation
    
    // Create chatContent.
    chatContent = [[UITableView alloc] initWithFrame:
                   CGRectMake(0.0f, 0.0f, self.view.frame.size.width,
                              self.view.frame.size.height-kChatBarHeight1)];
    chatContent.clearsContextBeforeDrawing = NO;
    chatContent.delegate = self;
    chatContent.dataSource = self;
    chatContent.contentInset = UIEdgeInsetsMake(7.0f, 0.0f, 0.0f, 0.0f);
    chatContent.backgroundColor = CHAT_BACKGROUND_COLOR;
    chatContent.separatorStyle = UITableViewCellSeparatorStyleNone;
    chatContent.autoresizingMask = UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:chatContent];
    
    // Create chatBar.
    chatBar = [[UIImageView alloc] initWithFrame:
               CGRectMake(0.0f, self.view.frame.size.height-kChatBarHeight1,
                          self.view.frame.size.width, kChatBarHeight1)];
    chatBar.clearsContextBeforeDrawing = NO;
    chatBar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleWidth;
    chatBar.image = [[UIImage imageNamed:@"ChatBar.png"]
                     stretchableImageWithLeftCapWidth:18 topCapHeight:20];
    chatBar.userInteractionEnabled = YES;
    
    // Create chatInput.
    chatInput = [[UITextView alloc] initWithFrame:CGRectMake(10.0f, 9.0f, 234.0f, 22.0f)];
    chatInput.contentSize = CGSizeMake(234.0f, 22.0f);
    chatInput.delegate = self;
    chatInput.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    chatInput.scrollEnabled = NO; // not initially
    chatInput.scrollIndicatorInsets = UIEdgeInsetsMake(5.0f, 0.0f, 4.0f, -2.0f);
    chatInput.clearsContextBeforeDrawing = NO;
    chatInput.font = [UIFont systemFontOfSize:kMessageFontSize];
    chatInput.dataDetectorTypes = UIDataDetectorTypeAll;
    chatInput.backgroundColor = [UIColor clearColor];
    previousContentHeight = chatInput.contentSize.height;
    [chatBar addSubview:chatInput];
    
    // Create sendButton.
    sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
    sendButton.clearsContextBeforeDrawing = NO;
    sendButton.frame = CGRectMake(chatBar.frame.size.width - 70.0f, 8.0f, 64.0f, 26.0f);
    sendButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | // multi-line input
    UIViewAutoresizingFlexibleLeftMargin;                       // landscape
    UIImage *sendButtonBackground = [UIImage imageNamed:@"SendButton.png"];
    [sendButton setBackgroundImage:sendButtonBackground forState:UIControlStateNormal];
    [sendButton setBackgroundImage:sendButtonBackground forState:UIControlStateDisabled];
    sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    sendButton.titleLabel.shadowOffset = CGSizeMake(0.0, -1.0);
    [sendButton setTitle:@"Send" forState:UIControlStateNormal];
    UIColor *shadowColor = [[UIColor alloc] initWithRed:0.325f green:0.463f blue:0.675f alpha:1.0f];
    [sendButton setTitleShadowColor:shadowColor forState:UIControlStateNormal];
 
    [sendButton addTarget:self action:@selector(sendMessage)
         forControlEvents:UIControlEventTouchUpInside];
    //    // The following three lines aren't necessary now that we'are using background image.
    //    sendButton.backgroundColor = [UIColor clearColor];
    //    sendButton.layer.cornerRadius = 13;
    //    sendButton.clipsToBounds = YES;
    //[self resetSendButton]; // disable initially
    [chatBar addSubview:sendButton];
    
    [self.view addSubview:chatBar];
    [self.view sendSubviewToBack:chatBar];
    
    //    // Test with lots of messages.
    //    NSDate *before = [NSDate date];
    //    for (NSUInteger i = 0; i < 500; i++) {
    //        Message *msg = (Message *)[NSEntityDescription
    //                                   insertNewObjectForEntityForName:@"Message"
    //                                   inManagedObjectContext:managedObjectContext];
    //    msg.text = [NSString stringWithFormat:@"This is message number %d", i];
    //    NSDate *now = [[NSDate alloc] init]; msg.sentDate = now; [now release];
    //    }
    ////    sleep(2);
    //    NSLog(@"Creating messages in memory takes %f seconds", [before timeIntervalSinceNow]);
    //    NSError *error;
    //    if (![managedObjectContext save:&error]) {
    //        // TODO: Handle the error appropriately.
    //        NSLog(@"Mass message creation error %@, %@", error, [error userInfo]);
    //    }
    //    NSLog(@"Saving messages to disc takes %f seconds", [before timeIntervalSinceNow]);
    
    [self loadMessages];
    // TODO: Implement check-box edit mode like iPhone Messages does. (Icebox)
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    [self scrollToBottomAnimated:NO];
}

- (void)loadMessages {
    [self fetchResults];
    
    // Construct cellMap from fetchedObjects.
    cellMap = [[NSMutableArray alloc]
               initWithCapacity:[[fetchedResultsController fetchedObjects] count]*2];
    
    for (XMPPMessageArchiving_Message_CoreDataObject *message in [fetchedResultsController fetchedObjects]) {
        if ([message.bareJid isEqualToJID:self.conversation.bareJid]) {
            [self addMessage:message];
        }
    }
    [chatContent reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated]; // below: work around for [chatContent flashScrollIndicators]
    NSLog(@"DNMessageViewController viewWillAppear");
    [chatContent performSelector:@selector(flashScrollIndicators) withObject:nil afterDelay:0.0];
}

- (void)viewDidDisappear:(BOOL)animated {
    [chatInput resignFirstResponder];
    [super viewDidDisappear:animated];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:(BOOL)editing animated:(BOOL)animated];
    [chatContent setEditing:(BOOL)editing animated:(BOOL)animated]; // forward method call
    //    chatContent.separatorStyle = editing ?
    //            UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;
    
    if (editing) {
        UIBarButtonItem *clearAllButton = [[UIBarButtonItem alloc] initWithTitle:@"Clear All" style:UIBarButtonItemStylePlain target:Nil action:@selector(clearAll)];
        //UIBarButtonItem *clearAllButton = BAR_BUTTON(NSLocalizedString(@"Clear All", nil), @selector(clearAll));
        self.navigationItem.leftBarButtonItem = clearAllButton;
    } else {
        self.navigationItem.leftBarButtonItem = nil;
    }
    
    //    if ([chatInput isFirstResponder]) {
    //        NSLog(@"resign first responder");
    //        [chatInput resignFirstResponder];
    //    }
}

- (void)textViewDidChange:(UITextView *)textView {
    CGFloat contentHeight = textView.contentSize.height - kMessageFontSize + 2.0f;
    NSString *rightTrimmedText = @"";
    
    //    NSLog(@"contentOffset: (%f, %f)", textView.contentOffset.x, textView.contentOffset.y);
    //    NSLog(@"contentInset: %f, %f, %f, %f", textView.contentInset.top, textView.contentInset.right,
    //          textView.contentInset.bottom, textView.contentInset.left);
    //    NSLog(@"contentSize.height: %f", contentHeight);
    
    
    if ([textView hasText]) {
        rightTrimmedText = [textView.text
                            stringByTrimmingTrailingWhitespaceAndNewlineCharacters];
        
        //        if (textView.text.length > 1024) { // truncate text to 1024 chars
        //            textView.text = [textView.text substringToIndex:1024];
        //        }
        
        // Resize textView to contentHeight
        if (contentHeight != previousContentHeight) {
            if (contentHeight <= kContentHeightMax) { // limit chatInputHeight <= 4 lines
                NSLog(@"Shrinking");
                /*CGFloat chatBarHeight = contentHeight + 18.0f;
                SET_CHAT_BAR_HEIGHT(chatBarHeight);
                if (previousContentHeight > kContentHeightMax) {
                    textView.scrollEnabled = NO;
                }
                textView.contentOffset = CGPointMake(0.0f, 6.0f); // fix quirk
                [self scrollToBottomAnimated:YES];*/
            } else if (previousContentHeight <= kContentHeightMax) { // grow
                textView.scrollEnabled = YES;
                textView.contentOffset = CGPointMake(0.0f, contentHeight-68.0f); // shift to bottom
                if (previousContentHeight < kContentHeightMax) {
                    EXPAND_CHAT_BAR_HEIGHT;
                    [self scrollToBottomAnimated:YES];
                }
            }
        }
    } else { // textView is empty
        if (previousContentHeight > 22.0f) {
            RESET_CHAT_BAR_HEIGHT;
            if (previousContentHeight > kContentHeightMax) {
                textView.scrollEnabled = NO;
            }
        }
        textView.contentOffset = CGPointMake(0.0f, 6.0f); // fix quirk
    }
    
    // Enable sendButton if chatInput has non-blank text, disable otherwise.
    /*if (rightTrimmedText.length > 0) {
        [self enableSendButton];
    } else {
        [self disableSendButton];
    }*/
    
    previousContentHeight = contentHeight;
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range
 replacementText:(NSString *)text {
    textView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, 3.0f, 0.0f);
    return YES;
}

- (void)enableSendButton {
    if (sendButton.enabled == NO) {
        sendButton.enabled = YES;
        sendButton.titleLabel.alpha = 1.0f;
    }
}

- (void)disableSendButton {
    if (sendButton.enabled == YES) {
        [self resetSendButton];
    }
}

- (void)resetSendButton {
    sendButton.enabled = NO;
    sendButton.titleLabel.alpha = 0.5f; // Sam S. says 0.4f
}

- (void)keyboardWillShow:(NSNotification *)notification {
    [self resizeViewWithOptions:[notification userInfo]];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [self resizeViewWithOptions:[notification userInfo]];
}

- (void)resizeViewWithOptions:(NSDictionary *)options {
    NSTimeInterval animationDuration;
    UIViewAnimationCurve animationCurve;
    CGRect keyboardEndFrame;
    [[options objectForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&animationCurve];
    [[options objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    [[options objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardEndFrame];
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationCurve:animationCurve];
    [UIView setAnimationDuration:animationDuration];
    CGRect viewFrame = self.view.frame;
    NSLog(@"viewFrame y: %@", NSStringFromCGRect(viewFrame));
    
    //    // For testing.
    //    NSLog(@"keyboardEnd: %@", NSStringFromCGRect(keyboardEndFrame));
    //    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc]
    //                             initWithBarButtonSystemItem:UIBarButtonSystemItemDone
    //                             target:chatInput action:@selector(resignFirstResponder)];
    //    self.navigationItem.leftBarButtonItem = doneButton;
    //    [doneButton release];
    
    CGRect keyboardFrameEndRelative = [self.view convertRect:keyboardEndFrame fromView:nil];
    NSLog(@"self.view: %@", self.view);
    NSLog(@"keyboardFrameEndRelative: %@", NSStringFromCGRect(keyboardFrameEndRelative));
    
    viewFrame.size.height =  keyboardFrameEndRelative.origin.y;
    self.view.frame = viewFrame;
    [UIView commitAnimations];
    
    [self scrollToBottomAnimated:YES];
    
    chatInput.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, 3.0f, 0.0f);
    chatInput.contentOffset = CGPointMake(0.0f, 6.0f); // fix quirk
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    NSInteger bottomRow = [cellMap count] - 1;
    if (bottomRow >= 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:bottomRow inSection:0];
        NSLog(@"bottom row: %d, index path: %d", bottomRow, [chatContent numberOfRowsInSection:0]);
        [chatContent scrollToRowAtIndexPath:indexPath
                           atScrollPosition:UITableViewScrollPositionBottom animated:animated];
    }
}

- (void)sendMessage {
    //    // TODO: Show progress indicator like iPhone Message app does. (Icebox)
    //[activityIndicator startAnimating];
    
    //NO TRIMMED MESSSAGES
    /*NSString *rightTrimmedMessage = [chatInput.text stringByTrimmingTrailingWhitespaceAndNewlineCharacters];
    
    // Don't send blank messages.
    if (rightTrimmedMessage.length == 0) {
        [self clearChatInput];
        return;
    }*/
    
    // Create new message and save to Core Data.
    XMPPMessageArchivingCoreDataStorage *storage = [XMPPMessageArchivingCoreDataStorage sharedInstance];
    NSManagedObjectContext *moc = [storage mainThreadManagedObjectContext];

    XMPPMessageArchiving_Message_CoreDataObject *newMessage = (XMPPMessageArchiving_Message_CoreDataObject *)[NSEntityDescription
                                      insertNewObjectForEntityForName:@"XMPPMessageArchiving_Message_CoreDataObject"
                                      inManagedObjectContext:moc];
    
    newMessage.body = chatInput.text;
    NSDate *now = [[NSDate alloc] init]; newMessage.timestamp = now;
    newMessage.isOutgoing = YES;
    
    // Message to send
    NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
    [body setStringValue:chatInput.text];
    
    NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
    [message addAttributeWithName:@"type" stringValue:@"chat"];
    [message addAttributeWithName:@"to" stringValue:[self.conversation.bareJid full]];
    [message addChild:body];
    [[self.appDelegate xmppStream] sendElement:message];
    
    NSError *error;
    if (![moc save:&error]) {
        // TODO: Handle the error appropriately.
        NSLog(@"sendMessage error %@, %@", error, [error userInfo]);
    }
    NSLog(@"number of chats: %d", [cellMap count]);
    [self addMessage:newMessage];
    [chatContent reloadData];
    NSLog(@"number of chats: %d", [cellMap count]);

    [self clearChatInput];
    
    [self scrollToBottomAnimated:YES]; // must come after RESET_CHAT_BAR_HEIGHT above
    
    // Play sound or buzz, depending on user settings.
    /*NSString *sendPath = [[NSBundle mainBundle] pathForResource:@"basicsound" ofType:@"wav"];
    CFURLRef baseURL = (CFURLRef)[NSURL fileURLWithPath:sendPath];
    AudioServicesCreateSystemSoundID(baseURL, &receiveMessageSound);
    AudioServicesPlaySystemSound(receiveMessageSound);*/
    //    AudioServicesPlayAlertSound(receiveMessageSound); // use for receiveMessage (sound & vibrate)
    //    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate); // explicit vibrate
}

- (void)clearChatInput {
    chatInput.text = @"";
    if (previousContentHeight > 22.0f) {
        RESET_CHAT_BAR_HEIGHT;
        chatInput.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, 3.0f, 0.0f);
        chatInput.contentOffset = CGPointMake(0.0f, 6.0f); // fix quirk
        [self scrollToBottomAnimated:YES];
    }
}

- (NSUInteger)addMessage:(XMPPMessageArchiving_Message_CoreDataObject *)message {
    // Show sentDates at most every 15 minutes.
    NSDate *currentSentDate = message.timestamp;
    NSUInteger numberOfObjectsAdded = 1;
    NSUInteger prevIndex = [cellMap count] - 1;
    
    // Show sentDates at most every 15 minutes.
    
    if([cellMap count]) {
        BOOL prevIsMessage = [[cellMap objectAtIndex:prevIndex] isKindOfClass:[XMPPMessageArchiving_Message_CoreDataObject class]];
        if(prevIsMessage) {
            XMPPMessageArchiving_Message_CoreDataObject *temp = [cellMap objectAtIndex:prevIndex];
            NSDate * previousSentDate = temp.timestamp;
            // if there has been more than a 15 min gap between this and the previous message!
            if([currentSentDate timeIntervalSinceDate:previousSentDate] > SECONDS_BETWEEN_MESSAGES)
            {
                [cellMap addObject:currentSentDate];
                numberOfObjectsAdded = 2;
            }
        }
    } else {
        // there are NO messages, definitely add a timestamp!
        [cellMap addObject:currentSentDate];
        numberOfObjectsAdded = 2;
    }
    
    [cellMap addObject:message];
    
    return numberOfObjectsAdded;
}

// Returns number of objects removed from cellMap (1 or 2).
- (NSUInteger)removeMessageAtIndex:(NSUInteger)index {
    //    NSLog(@"Delete message from cellMap");
    
    // Remove message from cellMap.
    [cellMap removeObjectAtIndex:index];
    NSUInteger numberOfObjectsRemoved = 1;
    NSUInteger prevIndex = index - 1;
    NSUInteger cellMapCount = [cellMap count];
    
    BOOL isLastObject = index == cellMapCount;
    BOOL prevIsDate = [[cellMap objectAtIndex:prevIndex] isKindOfClass:[NSDate class]];
    
    if ((isLastObject && prevIsDate) ||
        (prevIsDate && [[cellMap objectAtIndex:index] isKindOfClass:[NSDate class]])) {
        [cellMap removeObjectAtIndex:prevIndex];
        numberOfObjectsRemoved = 2;
    }
    return numberOfObjectsRemoved;
}

- (void)clearAll {
    UIActionSheet *confirm = [[UIActionSheet alloc]
                              initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel"
                              destructiveButtonTitle:NSLocalizedString(@"Clear Conversation", nil)
                              otherButtonTitles:nil];
    
	// use the same style as the nav bar
	confirm.actionSheetStyle = self.navigationController.navigationBar.barStyle;
    
    [confirm showFromBarButtonItem:self.navigationItem.leftBarButtonItem animated:YES];
    //    [confirm showInView:self.view];
    
}

- (void)actionSheet:(UIActionSheet *)modalView clickedButtonAtIndex:(NSInteger)buttonIndex {
	switch (buttonIndex) {
		case ClearConversationButtonIndex: {
            NSError *error;
            fetchedResultsController.delegate = nil;               // turn off delegate callbacks
            for (XMPPMessageArchiving_Message_CoreDataObject *message in [fetchedResultsController fetchedObjects]) {
                [managedObjectContext deleteObject:message];
            }
            if (![managedObjectContext save:&error]) {
                // TODO: Handle the error appropriately.
                NSLog(@"Delete message error %@, %@", error, [error userInfo]);
            }
            fetchedResultsController.delegate = self;              // reconnect after mass delete
            if (![fetchedResultsController performFetch:&error]) { // resync controller
                // TODO: Handle the error appropriately.
                NSLog(@"fetchResults error %@, %@", error, [error userInfo]);
            }
            
            [cellMap removeAllObjects];
            [chatContent reloadData];
            
            [self setEditing:NO animated:NO];
            break;
		}
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [cellMap count];
}

#define SENT_DATE_TAG 101
#define TEXT_TAG 102
#define BACKGROUND_TAG 103

static NSString *kMessageCell = @"MessageCell";

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UILabel *msgSentDate;
    UIImageView *msgBackground;
    UILabel *msgText;
    
    //    NSLog(@"cell for row: %d", [indexPath row]);
    
    NSObject *object = [cellMap objectAtIndex:[indexPath row]];
    UITableViewCell *cell;
    
    // Handle sentDate (NSDate).
    if ([object isKindOfClass:[NSDate class]]) {
        static NSString *kSentDateCellId = @"SentDateCell";
        cell = [tableView dequeueReusableCellWithIdentifier:kSentDateCellId];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                           reuseIdentifier:kSentDateCellId];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            // Create message sentDate lable
            msgSentDate = [[UILabel alloc] initWithFrame:
                           CGRectMake(-2.0f, 0.0f,
                                      tableView.frame.size.width, kSentDateFontSize+8.0f)];
            msgSentDate.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            msgSentDate.clearsContextBeforeDrawing = NO;
            msgSentDate.tag = SENT_DATE_TAG;
            msgSentDate.font = [UIFont boldSystemFontOfSize:kSentDateFontSize];
            msgSentDate.lineBreakMode = UILineBreakModeTailTruncation;
            msgSentDate.textAlignment = UITextAlignmentCenter;
            msgSentDate.backgroundColor = CHAT_BACKGROUND_COLOR; // clearColor slows performance
            msgSentDate.textColor = [UIColor grayColor];
            [cell addSubview:msgSentDate];
            //            // Uncomment for view layout debugging.
            //            cell.contentView.backgroundColor = [UIColor orangeColor];
            //            msgSentDate.backgroundColor = [UIColor orangeColor];
        } else {
            msgSentDate = (UILabel *)[cell viewWithTag:SENT_DATE_TAG];
        }
        
        static NSDateFormatter *dateFormatter = nil;
        if (dateFormatter == nil) {
            dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateStyle:NSDateFormatterMediumStyle]; // Jan 1, 2010
            [dateFormatter setTimeStyle:NSDateFormatterShortStyle];  // 1:43 PM
            
            // TODO: Get locale from iPhone system prefs. Then, move this to viewDidAppear.
            NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
            [dateFormatter setLocale:usLocale];
        }
        
        msgSentDate.text = [dateFormatter stringFromDate:(NSDate *)object];
        
        return cell;
    }
    
    // Handle Message object.
    cell = [tableView dequeueReusableCellWithIdentifier:kMessageCell];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:kMessageCell];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = CHAT_BACKGROUND_COLOR;
        
        // Create message background image view
        msgBackground = [[UIImageView alloc] init];
        msgBackground.clearsContextBeforeDrawing = NO;
        msgBackground.tag = BACKGROUND_TAG;
        msgBackground.backgroundColor = CHAT_BACKGROUND_COLOR; // clearColor slows performance
        [cell.contentView addSubview:msgBackground];
        
        // Create message text label
        msgText = [[UILabel alloc] init];
        msgText.clearsContextBeforeDrawing = NO;
        msgText.tag = TEXT_TAG;
        msgText.backgroundColor = [UIColor clearColor];
        msgText.numberOfLines = 0;
        msgText.lineBreakMode = UILineBreakModeWordWrap;
        msgText.font = [UIFont systemFontOfSize:kMessageFontSize];
        [cell.contentView addSubview:msgText];
    } else {
        msgBackground = (UIImageView *)[cell.contentView viewWithTag:BACKGROUND_TAG];
        msgText = (UILabel *)[cell.contentView viewWithTag:TEXT_TAG];
    }
    
    // Configure the cell to show the message in a bubble. Layout message cell & its subviews.
    CGSize size = [[(XMPPMessageArchiving_Message_CoreDataObject *)object body] sizeWithFont:[UIFont systemFontOfSize:kMessageFontSize]
                                       constrainedToSize:CGSizeMake(kMessageTextWidth, CGFLOAT_MAX)
                                           lineBreakMode:UILineBreakModeWordWrap];
    UIImage *bubbleImage;
    XMPPMessageArchiving_Message_CoreDataObject *message = (XMPPMessageArchiving_Message_CoreDataObject *)object;
    if (message.isOutgoing) { // right bubble
        CGFloat editWidth = tableView.editing ? 32.0f : 0.0f;
        msgBackground.frame = CGRectMake(tableView.frame.size.width-size.width-34.0f-editWidth,
                                         kMessageFontSize-13.0f, size.width+34.0f,
                                         size.height+12.0f);
        bubbleImage = [[UIImage imageNamed:@"ChatBubbleGreen.png"]
                       stretchableImageWithLeftCapWidth:15 topCapHeight:13];
        msgText.frame = CGRectMake(tableView.frame.size.width-size.width-22.0f-editWidth,
                                   kMessageFontSize-9.0f, size.width+5.0f, size.height);
        msgBackground.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        msgText.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        //        // Uncomment for view layout debugging.
        //        cell.contentView.backgroundColor = [UIColor blueColor];
    } else { // left bubble
        msgBackground.frame = CGRectMake(0.0f, kMessageFontSize-13.0f,
                                         size.width+34.0f, size.height+12.0f);
        bubbleImage = [[UIImage imageNamed:@"ChatBubbleGray.png"]
                       stretchableImageWithLeftCapWidth:23 topCapHeight:15];
        msgText.frame = CGRectMake(22.0f, kMessageFontSize-9.0f, size.width+5.0f, size.height);
        msgBackground.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        msgText.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    }
    msgBackground.image = bubbleImage;
    msgText.text = [(XMPPMessageArchiving_Message_CoreDataObject *)object body];
    
    // Mark message as read.
    // Let's instead do this (asynchronously) from loadView and iterate over all messages
    
    /*
    if (![(XMPPMessageArchiving_Message_CoreDataObject *)object read]) { // not read, so save as read
        [(XMPPMessageArchiving_Message_CoreDataObject *)object setRead:[NSNumber numberWithBool:YES]];
        NSError *error;
        if (![managedObjectContext save:&error]) {
            // TODO: Handle the error appropriately.
            NSLog(@"Save message as read error %@, %@", error, [error userInfo]);
        }
    }
     */
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return [[cellMap objectAtIndex:[indexPath row]] isKindOfClass:[XMPPMessageArchiving_Message_CoreDataObject class]];
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSObject *object = [cellMap objectAtIndex:[indexPath row]];
        if ([object isKindOfClass:[NSDate class]]) {
            return;
        }
        
        //        NSLog(@"Delete %@", object);
        
        // Remove message from managed object context by index path.
        XMPPMessageArchivingCoreDataStorage *storage = [XMPPMessageArchivingCoreDataStorage sharedInstance];
        NSManagedObjectContext *moc = [storage mainThreadManagedObjectContext];
        [moc deleteObject:(XMPPMessageArchiving_Message_CoreDataObject *)object];
        NSError *error;
        if (![moc save:&error]) {
            // TODO: Handle the error appropriately.
            NSLog(@"Delete message error %@, %@", error, [error userInfo]);
        }
        [tableView reloadData];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    //    NSLog(@"height for row: %d", [indexPath row]);
    
    NSObject *object = [cellMap objectAtIndex:[indexPath row]];
    
    // Set SentDateCell height.
    if ([object isKindOfClass:[NSDate class]]) {
        return kSentDateFontSize + 7.0f;
    }
    
    // Set MessageCell height.
    CGSize size = [[(XMPPMessageArchiving_Message_CoreDataObject *)object body] sizeWithFont:[UIFont systemFontOfSize:kMessageFontSize]
                                       constrainedToSize:CGSizeMake(kMessageTextWidth, CGFLOAT_MAX)
                                           lineBreakMode:UILineBreakModeWordWrap];
    return size.height + 17.0f;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing) { // disable slide to delete
        return UITableViewCellEditingStyleDelete;
        //        return 3; // used to work for check boxes
    }
    return UITableViewCellEditingStyleNone;
}

- (void)fetchResults {
    NSLog(@"fetch results (messages)");
    
    XMPPMessageArchivingCoreDataStorage *storage = [XMPPMessageArchivingCoreDataStorage sharedInstance];
    NSManagedObjectContext *moc = [storage mainThreadManagedObjectContext];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPMessageArchiving_Message_CoreDataObject"
                                              inManagedObjectContext:moc];
    
    NSSortDescriptor *sd1 = [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:YES];
    
    NSArray *sortDescriptors = [NSArray arrayWithObjects:sd1, nil];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:entity];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:moc sectionNameKeyPath:nil cacheName:@"MessageListCache"];
    
    NSError *error;
    BOOL rval = [fetchedResultsController performFetch:&error];
    
    if (!rval) {
        NSLog(@"error: %@", error);
    }
    [chatContent reloadData];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    
    NSArray *indexPaths;
    NSLog(@"changed object");
    
    switch(type) {
        case NSFetchedResultsChangeInsert: {
            NSUInteger cellCount = [cellMap count];
            
            NSIndexPath *firstIndexPath = [NSIndexPath indexPathForRow:cellCount inSection:0];
            
            if ([self addMessage:anObject] == 1) {
                //                NSLog(@"insert 1 row at index: %d", cellCount);
                indexPaths = [[NSArray alloc] initWithObjects:firstIndexPath, nil];
            } else { // 2
                //                NSLog(@"insert 2 rows at index: %d", cellCount);
                indexPaths = [[NSArray alloc] initWithObjects:firstIndexPath,
                              [NSIndexPath indexPathForRow:cellCount+1 inSection:0], nil];
            }
            
            [chatContent insertRowsAtIndexPaths:indexPaths
                               withRowAnimation:UITableViewRowAnimationNone];
            [self scrollToBottomAnimated:YES];
            break;
        }
        case NSFetchedResultsChangeDelete: {
            NSUInteger objectIndex = [cellMap indexOfObjectIdenticalTo:anObject];
            NSIndexPath *objectIndexPath = [NSIndexPath indexPathForRow:objectIndex inSection:0];
            
            if ([self removeMessageAtIndex:objectIndex] == 1) {
                //                NSLog(@"delete 1 row");
                indexPaths = [[NSArray alloc] initWithObjects:objectIndexPath, nil];
            } else { // 2
                //                NSLog(@"delete 2 rows");
                indexPaths = [[NSArray alloc] initWithObjects:objectIndexPath,
                              [NSIndexPath indexPathForRow:objectIndex-1 inSection:0], nil];
            }
            
            [chatContent deleteRowsAtIndexPaths:indexPaths
                               withRowAnimation:UITableViewRowAnimationNone];
            break;
        }
    }
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
