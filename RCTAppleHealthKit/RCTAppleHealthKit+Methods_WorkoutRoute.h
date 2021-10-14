//
//  RCTAppleHealthKit+Methods_WorkoutRoute.h
//  RCTAppleHealthKit
//
//  Created by Kevin Yulianto on 13/10/21.
//  Copyright © 2021 Greg Wilson. All rights reserved.
//

#import "RCTAppleHealthKit.h"

@interface RCTAppleHealthKit (Methods_WorkoutRoute)

/*@yulianto.kevin: adding anchored workouts routes*/
- (void)workoutRoute_getLocations:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback;
@end
