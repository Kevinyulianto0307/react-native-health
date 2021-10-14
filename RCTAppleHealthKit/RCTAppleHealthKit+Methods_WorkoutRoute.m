//
//  RCTAppleHealthKit+Methods_Workout.m
//  RCTAppleHealthKit
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "RCTAppleHealthKit+Methods_Workout.h"
#import "RCTAppleHealthKit+Utils.h"
#import "RCTAppleHealthKit+Queries.h"

@implementation RCTAppleHealthKit (Methods_WorkoutRoute)

- (void)workoutRoute_getLocations:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback
{
    HKWorkoutRoute *workoutRoute = [RCTAppleHealthKit hkWorkoutRouteFromOptions:input];
    void (^completion)(NSDictionary *results, NSError *error);
    
    completion = ^(NSDictionary *results, NSError *error) {
        if (results){
            callback(@[[NSNull null], results]);
            
            return;
        } else {
            NSLog(@"error getting samples: %@", error);
            callback(@[RCTMakeError(@"error getting samples", error, nil)]);
            
            return;
        }
    };
    
    [self fetchWorkoutRouteLocations:workoutRoute
                     completion:completion];
}
@end
