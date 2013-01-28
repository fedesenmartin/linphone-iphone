/* BuschJaegerMainView.m
 *
 * Copyright (C) 2011  Belledonne Comunications, Grenoble, France
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#import "BuschJaegerMainView.h"
#import "BuschJaegerUtils.h"
#include "lpconfig.h"

@implementation UINavigationControllerEx

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    [viewController view];
    UIViewController *oldTopViewController = self.topViewController;
    if ([[UIDevice currentDevice].systemVersion doubleValue] < 5.0) {
        [oldTopViewController viewWillDisappear:animated];
        [viewController viewWillAppear:animated];
    }
    [super pushViewController:viewController animated:animated];
    if ([[UIDevice currentDevice].systemVersion doubleValue] < 5.0) {
        [self.topViewController viewDidAppear:animated];
        [oldTopViewController viewDidDisappear:animated];
    }
}

- (NSArray*)popToViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if ([[UIDevice currentDevice].systemVersion doubleValue] < 5.0) {
        NSMutableArray *array = [NSMutableArray array];
        while([self.viewControllers count] > 1 && self.topViewController != viewController) {
            [array addObject:[self popViewControllerAnimated:animated]];
        }
        return array;
    }
    return [super popToViewController:viewController animated:animated];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    int count = [self.viewControllers count];
    if(count > 1) {
        if ([[UIDevice currentDevice].systemVersion doubleValue] < 5.0) {
            [self.topViewController viewWillDisappear:animated];
            UIViewController *nextView = nil;
            nextView = [self.viewControllers objectAtIndex:count - 2];
            
            [nextView viewWillAppear:animated];
        }
        UIViewController * ret = [super popViewControllerAnimated:animated];
        if ([[UIDevice currentDevice].systemVersion doubleValue] < 5.0) {
            [ret viewDidDisappear:animated];
            [self.topViewController viewDidAppear:animated];
        }
        return ret;
    }
    return nil;
}

@end

@implementation BuschJaegerMainView

@synthesize navigationController;
@synthesize callView;
@synthesize settingsView;
@synthesize manualSettingsView;
@synthesize welcomeView;
@synthesize historyView;
@synthesize historyDetailsView;

static BuschJaegerMainView* mainViewInstance=nil;



#pragma mark - Lifecycle Functions

- (void)initBuschJaegerMainView {
    assert (!mainViewInstance);
    mainViewInstance = self;
    loadCount = 0;
    historyTimer = [NSTimer scheduledTimerWithTimeInterval: 10.0
                                                    target: self
                                                  selector: @selector(updateIconBadge:)
                                                  userInfo: nil
                                                   repeats: YES];
    historyQueue = [[NSOperationQueue alloc] init];
    historyQueue.name = @"History queue";
    historyQueue.maxConcurrentOperationCount = 1;
}

- (id)init {
    self = [super init];
    if (self) {
		[self initBuschJaegerMainView];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
		[self initBuschJaegerMainView];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
		[self initBuschJaegerMainView];
	}
    return self;
}

- (void)dealloc {
    [navigationController release];
    [callView release];
    [settingsView release];
    [manualSettingsView release];
    [welcomeView release];
    [historyView release];
    [historyDetailsView release];
    
    [historyTimer invalidate];
    [historyQueue release];
    
    // Remove all observer
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}


#pragma mark - ViewController Functions

- (void)viewDidLoad {
    // Avoid IOS 4 bug
    if(loadCount++ > 0)
        return;
    
    [super viewDidLoad];
    
   // [self setWantsFullScreenLayout:TRUE];
    
    UIView *view = navigationController.view;
   // [view setFrame:[self.view bounds]];
    [self.view addSubview:view];
    [navigationController pushViewController:welcomeView animated:FALSE];
    [self networkUpdate:[[LinphoneManager instance].configuration.homeAP isEqualToData:[LinphoneManager getWifiData]]];
    [self updateIconBadge:nil];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    // Avoid IOS 4 bug
    loadCount--;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Set observer
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(callUpdateEvent:)
                                                 name:kLinphoneCallUpdate
                                               object:nil];
    
    // Set observer
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textReceivedEvent:)
                                                 name:kLinphoneTextReceived
                                               object:nil];
    // set observer
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkUpdateEvent:)
                                                 name:kLinphoneNetworkUpdate
                                               object:nil];
}

- (void)vieWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    // Remove observer
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kLinphoneCallUpdate
                                                  object:nil];
    
    // Remove observer
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kLinphoneTextReceived
                                                  object:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return [navigationController.topViewController shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}

- (NSUInteger)supportedInterfaceOrientations {
    return [navigationController.topViewController supportedInterfaceOrientations];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [BuschJaegerUtils resizeGradient:self.view];
}


#pragma mark - Event Functions

- (void)updateIconBadge:(id)info {
    if([historyQueue operationCount] == 0) {
        [historyQueue addOperationWithBlock:^(void) {
            if([[LinphoneManager instance] configuration].valid) {
                NSMutableSet *set = [[[LinphoneManager instance] configuration] getHistory];
                if(set != nil) {
                    int missed = [set count] - [[[LinphoneManager instance] configuration].history count];
                    if(missed < 0) missed = 0;
                    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:missed];
                }
            }
        }];
    }
}

- (void)callUpdateEvent: (NSNotification*) notif {
    LinphoneCall *call = [[notif.userInfo objectForKey: @"call"] pointerValue];
    LinphoneCallState state = [[notif.userInfo objectForKey: @"state"] intValue];
    [self callUpdate:call state:state animated:TRUE];
}


- (void)textReceivedEvent: (NSNotification*) notif {
    [self displayMessage:notif];
}

- (void)networkUpdateEvent: (NSNotification*) notif {
    [self networkUpdate:[[LinphoneManager instance].configuration.homeAP isEqualToData:[LinphoneManager getWifiData]]];
}


#pragma mark -

- (void)networkUpdate:(BOOL)home {
    if([LinphoneManager isLcReady]) {
        LinphoneCore *lc = [LinphoneManager getLc];
        LpConfig  *config =  linphone_core_get_config(lc);
        int upload, download;
        if(home) {
            upload = lp_config_get_int(config, "net", "home_upload_bw", 0);
            download = lp_config_get_int(config, "net", "home_download_bw", 0);

        } else {
            upload = lp_config_get_int(config, "net", "out_upload_bw", 0);
            download = lp_config_get_int(config, "net", "out_download_bw", 0);
        }
        linphone_core_set_upload_bandwidth(lc, upload);
        linphone_core_set_download_bandwidth(lc, download);
        [[LinphoneManager instance] reconfigureProxyConfigs];
    }
}

- (void)callUpdate:(LinphoneCall *)call state:(LinphoneCallState)state animated:(BOOL)animated {
    // Fake call update
    if(call == NULL) {
        return;
    }
    
    switch (state) {
		case LinphoneCallIncomingReceived:
        {
            [self displayIncomingCall:call];
        }
        case LinphoneCallOutgoingInit:
        {
            linphone_call_enable_camera(call, FALSE);
        }
        case LinphoneCallPausedByRemote:
		case LinphoneCallConnected:
        case LinphoneCallUpdating:
        {
            [navigationController popToViewController:welcomeView animated:FALSE];
            [navigationController pushViewController:callView animated:FALSE]; // No animation... Come back when Apple have learned how to create a good framework
            break;
        }
        case LinphoneCallError:
		case LinphoneCallEnd:
        {
            [self dismissIncomingCall:call];
            if ((linphone_core_get_calls([LinphoneManager getLc]) == NULL)) {
                [navigationController popToViewController:welcomeView animated:FALSE]; // No animation... Come back when Apple have learned how to create a good framework
            }
            [self updateIconBadge:nil];
			break;
        }
        default:
            break;
	}
}

- (void)dismissIncomingCall:(LinphoneCall*)call {
    LinphoneCallAppData* appData = (LinphoneCallAppData*) linphone_call_get_user_pointer(call);
    
    if(appData != nil && appData->notification != nil) {
        // cancel local notif if needed
        [[UIApplication sharedApplication] cancelLocalNotification:appData->notification];
        [appData->notification release];
    }
}

- (void)displayIncomingCall:(LinphoneCall *)call {
    if (![[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]
        || [UIApplication sharedApplication].applicationState ==  UIApplicationStateActive) {
        [[LinphoneManager instance] setSpeakerEnabled:TRUE];
        AudioServicesPlaySystemSound([LinphoneManager instance].sounds.call);
    }
}

- (void)displayMessage:(id)message {
    if (![[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]
		|| [UIApplication sharedApplication].applicationState ==  UIApplicationStateActive) {
        UIAlertView* error = [[UIAlertView alloc] initWithTitle:@"Welcome"
                                                        message: [NSString stringWithFormat:@"%@", [LinphoneManager instance].configuration.levelPushButton.name]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                              otherButtonTitles:nil,nil];
        [error show];
        [error release];
        [[LinphoneManager instance] setSpeakerEnabled:TRUE];
        AudioServicesPlayAlertSound([LinphoneManager instance].sounds.level);
    }
}

+ (BuschJaegerMainView *) instance {
    return mainViewInstance;
}


@end