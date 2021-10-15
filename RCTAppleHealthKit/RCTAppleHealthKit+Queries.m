//
//  RCTAppleHealthKit+Queries.m
//  RCTAppleHealthKit
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "RCTAppleHealthKit+Queries.h"
#import "RCTAppleHealthKit+Utils.h"
#import "RCTAppleHealthKit+TypesAndPermissions.h"

#import <React/RCTBridgeModule.h>
#import <React/RCTEventDispatcher.h>

@implementation RCTAppleHealthKit (Queries)

- (void)fetchMostRecentQuantitySampleOfType:(HKQuantityType *)quantityType
                                  predicate:(NSPredicate *)predicate
                                 completion:(void (^)(HKQuantity *, NSDate *, NSDate *, NSError *))completion {

    NSSortDescriptor *timeSortDescriptor = [[NSSortDescriptor alloc]
            initWithKey:HKSampleSortIdentifierEndDate
              ascending:NO
    ];

    HKSampleQuery *query = [[HKSampleQuery alloc]
            initWithSampleType:quantityType
                     predicate:predicate
                         limit:1
               sortDescriptors:@[timeSortDescriptor]
                resultsHandler:^(HKSampleQuery *query, NSArray *results, NSError *error) {

                      if (!results) {
                          if (completion) {
                              completion(nil, nil, nil, error);
                          }
                          return;
                      }

                      if (completion) {
                          // If quantity isn't in the database, return nil in the completion block.
                          HKQuantitySample *quantitySample = results.firstObject;
                          HKQuantity *quantity = quantitySample.quantity;
                          NSDate *startDate = quantitySample.startDate;
                          NSDate *endDate = quantitySample.endDate;
                          completion(quantity, startDate, endDate, error);
                      }
                }
    ];
    [self.healthStore executeQuery:query];
}

- (void)fetchQuantitySamplesOfType:(HKQuantityType *)quantityType
                              unit:(HKUnit *)unit
                         predicate:(NSPredicate *)predicate
                         ascending:(BOOL)asc
                             limit:(NSUInteger)lim
                        completion:(void (^)(NSArray *, NSError *))completion {

    NSSortDescriptor *timeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:HKSampleSortIdentifierEndDate
                                                                       ascending:asc];

    // declare the block
    void (^handlerBlock)(HKSampleQuery *query, NSArray *results, NSError *error);
    // create and assign the block
    handlerBlock = ^(HKSampleQuery *query, NSArray *results, NSError *error) {
        if (!results) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        if (completion) {
            NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

            dispatch_async(dispatch_get_main_queue(), ^{

                for (HKQuantitySample *sample in results) {
                    HKQuantity *quantity = sample.quantity;
                    double value = [quantity doubleValueForUnit:unit];

                    NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate];
                    NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate];

                    NSDictionary *elem = @{
                            @"value" : @(value),
                            @"id" : [[sample UUID] UUIDString],
                            @"sourceName" : [[[sample sourceRevision] source] name],
                            @"sourceId" : [[[sample sourceRevision] source] bundleIdentifier],
                            @"startDate" : startDateString,
                            @"endDate" : endDateString,
                    };

                    [data addObject:elem];
                }

                completion(data, error);
            });
        }
    };

    HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:quantityType
                                                           predicate:predicate
                                                               limit:lim
                                                     sortDescriptors:@[timeSortDescriptor]
                                                      resultsHandler:handlerBlock];

    [self.healthStore executeQuery:query];
}

- (void)fetchSamplesOfType:(HKSampleType *)type
                      unit:(HKUnit *)unit
                 predicate:(NSPredicate *)predicate
                 ascending:(BOOL)asc
                     limit:(NSUInteger)lim
                completion:(void (^)(NSArray *, NSError *))completion {

    NSSortDescriptor *timeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:HKSampleSortIdentifierEndDate
                                                                       ascending:asc];

    // declare the block
    void (^handlerBlock)(HKSampleQuery *query, NSArray *results, NSError *error);

    // create and assign the block
    handlerBlock = ^(HKSampleQuery *query, NSArray *results, NSError *error) {
        if (!results) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        if (completion) {
            NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

            dispatch_async(dispatch_get_main_queue(), ^{
                if (type == [HKObjectType workoutType]) {
                    for (HKWorkout *sample in results) {
                        @try {
                            double energy =  [[sample totalEnergyBurned] doubleValueForUnit:[HKUnit kilocalorieUnit]];
                            double distance = [[sample totalDistance] doubleValueForUnit:[HKUnit mileUnit]];
                            NSString *type = [RCTAppleHealthKit stringForHKWorkoutActivityType:[sample workoutActivityType]];

                            NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate];
                            NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate];

                            bool isTracked = true;
                            if ([[sample metadata][HKMetadataKeyWasUserEntered] intValue] == 1) {
                                isTracked = false;
                            }

                            NSString* device = @"";
                            if (@available(iOS 11.0, *)) {
                                device = [[sample sourceRevision] productType];
                            } else {
                                device = [[sample device] name];
                                if (!device) {
                                    device = @"iPhone";
                                }
                            }

                            NSDictionary *elem = @{
                                                   @"activityId" : [NSNumber numberWithInt:[sample workoutActivityType]],
                                                   @"id" : [[sample UUID] UUIDString],
                                                   @"activityName" : type,
                                                   @"calories" : @(energy),
                                                   @"tracked" : @(isTracked),
                                                   @"metadata" : [sample metadata],
                                                   @"sourceName" : [[[sample sourceRevision] source] name],
                                                   @"sourceId" : [[[sample sourceRevision] source] bundleIdentifier],
                                                   @"device": device,
                                                   @"distance" : @(distance),
                                                   @"start" : startDateString,
                                                   @"end" : endDateString
                                                   };

                            [data addObject:elem];
                        } @catch (NSException *exception) {
                            NSLog(@"RNHealth: An error occured while trying to add sample from: %@ ", [[[sample sourceRevision] source] bundleIdentifier]);
                        }
                    }
                } else {
                    for (HKQuantitySample *sample in results) {
                        @try {
                            HKQuantity *quantity = sample.quantity;
                            double value = [quantity doubleValueForUnit:unit];

                            NSString * valueType = @"quantity";
                            if (unit == [HKUnit mileUnit]) {
                                valueType = @"distance";
                            }

                            NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate];
                            NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate];

                            bool isTracked = true;
                            if ([[sample metadata][HKMetadataKeyWasUserEntered] intValue] == 1) {
                                isTracked = false;
                            }

                            NSString* device = @"";
                            if (@available(iOS 11.0, *)) {
                                device = [[sample sourceRevision] productType];
                            } else {
                                device = [[sample device] name];
                                if (!device) {
                                    device = @"iPhone";
                                }
                            }

                            NSDictionary *elem = @{
                                                   valueType : @(value),
                                                   @"tracked" : @(isTracked),
                                                   @"sourceName" : [[[sample sourceRevision] source] name],
                                                   @"sourceId" : [[[sample sourceRevision] source] bundleIdentifier],
                                                   @"device": device,
                                                   @"start" : startDateString,
                                                   @"end" : endDateString
                                                   };

                            [data addObject:elem];
                        } @catch (NSException *exception) {
                            NSLog(@"RNHealth: An error occured while trying to add sample from: %@ ", [[[sample sourceRevision] source] bundleIdentifier]);
                        }
                    }
                }

                completion(data, error);
            });
        }
    };

    HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:type
                                                           predicate:predicate
                                                               limit:lim
                                                     sortDescriptors:@[timeSortDescriptor]
                                                      resultsHandler:handlerBlock];

    [self.healthStore executeQuery:query];
}

- (void)fetchClinicalRecordsOfType:(HKClinicalType *)type
                         predicate:(NSPredicate *)predicate
                         ascending:(BOOL)asc
                             limit:(NSUInteger)lim
                        completion:(void (^)(NSArray *, NSError *))completion {
    NSSortDescriptor *timeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:HKSampleSortIdentifierEndDate ascending:asc];
    
    void (^handlerBlock)(HKSampleQuery *query, NSArray *results, NSError *error);

    handlerBlock = ^(HKSampleQuery *query, NSArray *results, NSError *error) {
        if (!results) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }
        if (completion) {
            NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                for (HKClinicalRecord *record in results) {
                    NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:record.startDate];
                    NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:record.endDate];
                    
                    NSError *jsonE = nil;
                    NSArray *fhirData = [NSJSONSerialization JSONObjectWithData:record.FHIRResource.data options: NSJSONReadingMutableContainers error: &jsonE];

                    if (!fhirData) {
                      completion(nil, jsonE);
                    }
                    
                    NSString *fhirRelease;
                    NSString *fhirVersion;
                    if (@available(iOS 14.0, *)) {
                        HKFHIRVersion *fhirResourceVersion = record.FHIRResource.FHIRVersion;
                        fhirRelease = fhirResourceVersion.FHIRRelease;
                        fhirVersion = fhirResourceVersion.stringRepresentation;
                    } else {
                        // iOS < 14 uses DSTU2
                        fhirRelease = @"DSTU2";
                        fhirVersion = @"1.0.2";
                    }
                        
                    NSDictionary *elem = @{
                        @"id" : [[record UUID] UUIDString],
                        @"sourceName" : [[[record sourceRevision] source] name],
                        @"sourceId" : [[[record sourceRevision] source] bundleIdentifier],
                        @"startDate" : startDateString,
                        @"endDate" : endDateString,
                        @"displayName" : record.displayName,
                        @"fhirData": fhirData,
                        @"fhirRelease": fhirRelease,
                        @"fhirVersion": fhirVersion,
                    };
                    [data addObject:elem];
                }
                completion(data, error);
            });
        }
    };
    
    HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:type predicate:predicate limit:lim sortDescriptors:@[timeSortDescriptor] resultsHandler:handlerBlock];
    [self.healthStore executeQuery:query];
}

- (void)fetchWorkouts:(HKSampleType *)type
                    predicate:(NSPredicate *)predicate
                       anchor:(HKQueryAnchor *)anchor
                        limit:(NSUInteger)lim
                   completion:(void (^)(NSDictionary *, NSError *))completion {
    // declare the block
    void (^handlerBlock)(HKAnchoredObjectQuery *query, NSArray<__kindof HKSample *> *sampleObjects, NSArray<HKDeletedObject *> *deletedObjects, HKQueryAnchor *newAnchor, NSError *error);

    // create and assign the block
    handlerBlock = ^(HKAnchoredObjectQuery *query, NSArray<__kindof HKSample *> *sampleObjects, NSArray<HKDeletedObject *> *deletedObjects, HKQueryAnchor *newAnchor, NSError *error) {

        if (!sampleObjects) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        if (completion) {
            NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

            dispatch_async(dispatch_get_main_queue(), ^{
                for (HKWorkout *sample in sampleObjects) {
//                    double energy =  [[sample totalEnergyBurned] doubleValueForUnit:[HKUnit kilocalorieUnit]];
//                    double distance = [[sample totalDistance] doubleValueForUnit:[HKUnit mileUnit]];
//                    double duration = [sample duration];
//
//
//
//                    NSString *type = [RCTAppleHealthKit stringForHKWorkoutActivityType:[sample workoutActivityType]];
//
//                    NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate];
//                    NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate];
//
//
//                    bool isTracked = true;
//                    if ([[sample metadata][HKMetadataKeyWasUserEntered] intValue] == 1) {
//                        isTracked = false;
//                    }
//
//                    NSString* device = @"";
//                    if (@available(iOS 11.0, *)) {
//                        device = [[sample sourceRevision] productType];
//                    } else {
//                        device = [[sample device] name];
//                        if (!device) {
//                            device = @"iPhone";
//                        }
//                    }
//
//                    NSDictionary *elem = @{
//                       @"activityId" : [NSNumber numberWithInt:[sample workoutActivityType]],
//                       @"id" : [[sample UUID] UUIDString],
//                       @"activityName" : type,
//                       @"calories" : @(energy),
//                       @"tracked" : @(isTracked),
//                       @"metadata" : [sample metadata],
//                       @"sourceName" : [[[sample sourceRevision] source] name],
//                       @"sourceId" : [[[sample sourceRevision] source] bundleIdentifier],
//                       @"device": device,
//                       @"distance" : @(distance),
//                       @"start" : startDateString,
//                       @"end" : endDateString
//                    };
                    
                    NSMutableDictionary *productSample = [sample mutableCopy];
//                    productSample[@"device"] = device;

                    [data addObject:productSample];
                    
                }
                
                NSData *anchorData = [NSKeyedArchiver archivedDataWithRootObject:newAnchor];
                NSString *anchorString = [anchorData base64EncodedStringWithOptions:0];
                completion(@{
                            @"anchor": anchorString,
                            @"data": data,
                        }, error);
            });
        }
    };
    
    HKAnchoredObjectQuery *query = [[HKAnchoredObjectQuery alloc] initWithType:type
                                                                     predicate:predicate
                                                                        anchor:anchor
                                                                         limit:lim
                                                                resultsHandler:handlerBlock];
    
    [self.healthStore executeQuery:query];
}



- (void)fetchAnchoredWorkouts:(HKSampleType *)type
                    predicate:(NSPredicate *)predicate
                       anchor:(HKQueryAnchor *)anchor
                        limit:(NSUInteger)lim
                   completion:(void (^)(NSDictionary *, NSError *))completion {

    // declare the block
    void (^handlerBlock)(HKAnchoredObjectQuery *query, NSArray<__kindof HKSample *> *sampleObjects, NSArray<HKDeletedObject *> *deletedObjects, HKQueryAnchor *newAnchor, NSError *error);

    // create and assign the block
    handlerBlock = ^(HKAnchoredObjectQuery *query, NSArray<__kindof HKSample *> *sampleObjects, NSArray<HKDeletedObject *> *deletedObjects, HKQueryAnchor *newAnchor, NSError *error) {

        if (!sampleObjects) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        if (completion) {
            NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

            dispatch_async(dispatch_get_main_queue(), ^{
                for (HKWorkout *sample in sampleObjects) {
                    @try {
                        double energy =  [[sample totalEnergyBurned] doubleValueForUnit:[HKUnit kilocalorieUnit]];
                        double distance = [[sample totalDistance] doubleValueForUnit:[HKUnit mileUnit]];
                        NSString *type = [RCTAppleHealthKit stringForHKWorkoutActivityType:[sample workoutActivityType]];

                        NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate];
                        NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate];

                        bool isTracked = true;
                        if ([[sample metadata][HKMetadataKeyWasUserEntered] intValue] == 1) {
                            isTracked = false;
                        }

                        NSString* device = @"";
                        if (@available(iOS 11.0, *)) {
                            device = [[sample sourceRevision] productType];
                        } else {
                            device = [[sample device] name];
                            if (!device) {
                                device = @"iPhone";
                            }
                        }

                        NSDictionary *elem = @{
                                               @"activityId" : [NSNumber numberWithInt:[sample workoutActivityType]],
                                               @"id" : [[sample UUID] UUIDString],
                                               @"activityName" : type,
                                               @"calories" : @(energy),
                                               @"tracked" : @(isTracked),
                                               @"metadata" : [sample metadata],
                                               @"sourceName" : [[[sample sourceRevision] source] name],
                                               @"sourceId" : [[[sample sourceRevision] source] bundleIdentifier],
                                               @"device": device,
                                               @"distance" : @(distance),
                                               @"start" : startDateString,
                                               @"end" : endDateString
                                               };

                        [data addObject:elem];
                    } @catch (NSException *exception) {
                        NSLog(@"RNHealth: An error occured while trying to add workout sample from: %@ ", [[[sample sourceRevision] source] bundleIdentifier]);
                    }
                }
                
                NSData *anchorData = [NSKeyedArchiver archivedDataWithRootObject:newAnchor];
                NSString *anchorString = [anchorData base64EncodedStringWithOptions:0];
                completion(@{
                            @"anchor": anchorString,
                            @"data": data,
                        }, error);
            });
        }
    };
    
    HKAnchoredObjectQuery *query = [[HKAnchoredObjectQuery alloc] initWithType:type
                                                                     predicate:predicate
                                                                        anchor:anchor
                                                                         limit:lim
                                                                resultsHandler:handlerBlock];

    [self.healthStore executeQuery:query];
}

- (void)fetchSleepCategorySamplesForPredicate:(NSPredicate *)predicate
                                        limit:(NSUInteger)lim
                                   completion:(void (^)(NSArray *, NSError *))completion {

    NSSortDescriptor *timeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:HKSampleSortIdentifierEndDate
                                                                       ascending:false];


    // declare the block
    void (^handlerBlock)(HKSampleQuery *query, NSArray *results, NSError *error);
    // create and assign the block
    handlerBlock = ^(HKSampleQuery *query, NSArray *results, NSError *error) {
        if (!results) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        if (completion) {
            NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

            dispatch_async(dispatch_get_main_queue(), ^{

                for (HKCategorySample *sample in results) {
                    NSInteger val = sample.value;

                    NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate];
                    NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate];

                    NSString *valueString;

                    switch (val) {
                      case HKCategoryValueSleepAnalysisInBed:
                        valueString = @"INBED";
                      break;
                      case HKCategoryValueSleepAnalysisAsleep:
                        valueString = @"ASLEEP";
                      break;
                     default:
                        valueString = @"UNKNOWN";
                     break;
                  }

                    NSDictionary *elem = @{
                            @"value" : valueString,
                            @"startDate" : startDateString,
                            @"endDate" : endDateString,
                            @"sourceName" : [[[sample sourceRevision] source] name],
                            @"sourceId" : [[[sample sourceRevision] source] bundleIdentifier],
                    };

                    [data addObject:elem];
                }

                completion(data, error);
            });
        }
    };

    HKCategoryType *categoryType =
    [HKObjectType categoryTypeForIdentifier:HKCategoryTypeIdentifierSleepAnalysis];

    HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:categoryType
                                                          predicate:predicate
                                                              limit:lim
                                                    sortDescriptors:@[timeSortDescriptor]
                                                     resultsHandler:handlerBlock];

    [self.healthStore executeQuery:query];
}

- (void)fetchCorrelationSamplesOfType:(HKQuantityType *)quantityType
                                 unit:(HKUnit *)unit
                            predicate:(NSPredicate *)predicate
                            ascending:(BOOL)asc
                                limit:(NSUInteger)lim
                           completion:(void (^)(NSArray *, NSError *))completion {

    NSSortDescriptor *timeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:HKSampleSortIdentifierEndDate
                                                                       ascending:asc];

    // declare the block
    void (^handlerBlock)(HKSampleQuery *query, NSArray *results, NSError *error);
    // create and assign the block
    handlerBlock = ^(HKSampleQuery *query, NSArray *results, NSError *error) {
        if (!results) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        if (completion) {
            NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

            dispatch_async(dispatch_get_main_queue(), ^{

                for (HKCorrelation *sample in results) {
                    NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate];
                    NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate];

                    NSDictionary *elem = @{
                      @"correlation" : sample,
                      @"startDate" : startDateString,
                      @"endDate" : endDateString,
                    };
                    [data addObject:elem];
                }

                completion(data, error);
            });
        }
    };

    HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:quantityType
                                                           predicate:predicate
                                                               limit:lim
                                                     sortDescriptors:@[timeSortDescriptor]
                                                      resultsHandler:handlerBlock];

    [self.healthStore executeQuery:query];
}

- (void)fetchSumOfSamplesTodayForType:(HKQuantityType *)quantityType
                                 unit:(HKUnit *)unit
                           completion:(void (^)(double, NSError *))completionHandler {

    NSPredicate *predicate = [RCTAppleHealthKit predicateForSamplesToday];
    HKStatisticsQuery *query = [[HKStatisticsQuery alloc] initWithQuantityType:quantityType
                                                          quantitySamplePredicate:predicate
                                                          options:HKStatisticsOptionCumulativeSum
                                                          completionHandler:^(HKStatisticsQuery *query, HKStatistics *result, NSError *error) {
                                                                HKQuantity *sum = [result sumQuantity];
                                                                if (completionHandler) {
                                                                    double value = [sum doubleValueForUnit:unit];
                                                                    completionHandler(value, error);
                                                                }
                                                          }];

    [self.healthStore executeQuery:query];
}

- (void)fetchSumOfSamplesOnDayForType:(HKQuantityType *)quantityType
                                 unit:(HKUnit *)unit
                                 includeManuallyAdded:(BOOL)includeManuallyAdded
                                  day:(NSDate *)day
                           completion:(void (^)(double, NSDate *, NSDate *, NSError *))completionHandler {
    NSPredicate *dayPredicate = [RCTAppleHealthKit predicateForSamplesOnDay:day];
    NSPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[dayPredicate]];
    if (includeManuallyAdded == false) {
        NSPredicate *manualDataPredicate = [NSPredicate predicateWithFormat:@"metadata.%K != YES", HKMetadataKeyWasUserEntered];
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[dayPredicate, manualDataPredicate]];
    }
    HKStatisticsQuery *query = [[HKStatisticsQuery alloc] initWithQuantityType:quantityType
                                                          quantitySamplePredicate:predicate
                                                          options:HKStatisticsOptionCumulativeSum
                                                          completionHandler:^(HKStatisticsQuery *query, HKStatistics *result, NSError *error) {
                                                              if ([error.localizedDescription isEqualToString:@"No data available for the specified predicate."] && completionHandler) {
                                                                  completionHandler(0, day, day, nil);
                                                                } else if (completionHandler) {
                                                                    HKQuantity *sum = [result sumQuantity];
                                                                    NSDate *startDate = result.startDate;
                                                                    NSDate *endDate = result.endDate;
                                                                    double value = [sum doubleValueForUnit:unit];
                                                                    completionHandler(value, startDate, endDate, error);
                                                              }
                                                          }];

    [self.healthStore executeQuery:query];
}

- (void)fetchCumulativeSumStatisticsCollection:(HKQuantityType *)quantityType
                                          unit:(HKUnit *)unit
                                     startDate:(NSDate *)startDate
                                       endDate:(NSDate *)endDate
                                    completion:(void (^)(NSArray *, NSError *))completionHandler {

    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *interval = [[NSDateComponents alloc] init];
    interval.day = 1;

    NSDateComponents *anchorComponents = [calendar components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear
                                                     fromDate:[NSDate date]];
    anchorComponents.hour = 0;
    NSDate *anchorDate = [calendar dateFromComponents:anchorComponents];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"metadata.%K != YES AND %K >= %@ AND %K <= %@",
                              HKMetadataKeyWasUserEntered,
                              HKPredicateKeyPathEndDate, startDate,
                              HKPredicateKeyPathStartDate, endDate];
    // Create the query
    HKStatisticsCollectionQuery *query = [[HKStatisticsCollectionQuery alloc] initWithQuantityType:quantityType
                                                                           quantitySamplePredicate:predicate
                                                                                           options:HKStatisticsOptionCumulativeSum
                                                                                        anchorDate:anchorDate
                                                                                intervalComponents:interval];

    // Set the results handler
    query.initialResultsHandler = ^(HKStatisticsCollectionQuery *query, HKStatisticsCollection *results, NSError *error) {
        if (error) {
            // Perform proper error handling here
            NSLog(@"*** An error occurred while calculating the statistics: %@ ***",error.localizedDescription);
        }

        NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];
        [results enumerateStatisticsFromDate:startDate
                                      toDate:endDate
                                   withBlock:^(HKStatistics *result, BOOL *stop) {

                                       HKQuantity *quantity = result.sumQuantity;
                                       if (quantity) {
                                           NSDate *date = result.startDate;
                                           double value = [quantity doubleValueForUnit:[HKUnit countUnit]];
                                           NSLog(@"%@: %f", date, value);

                                           NSString *dateString = [RCTAppleHealthKit buildISO8601StringFromDate:date];
                                           NSArray *elem = @[dateString, @(value)];
                                           [data addObject:elem];
                                       }
                                   }];
        NSError *err;
        completionHandler(data, err);
    };

    [self.healthStore executeQuery:query];
}

- (void)fetchCumulativeSumStatisticsCollection:(HKQuantityType *)quantityType
                                          unit:(HKUnit *)unit
                                     startDate:(NSDate *)startDate
                                       endDate:(NSDate *)endDate
                                     ascending:(BOOL)asc
                                         limit:(NSUInteger)lim
                                    completion:(void (^)(NSArray *, NSError *))completionHandler {

    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *interval = [[NSDateComponents alloc] init];
    interval.day = 1;

    NSDateComponents *anchorComponents = [calendar components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear
                                                     fromDate:[NSDate date]];
    anchorComponents.hour = 0;
    NSDate *anchorDate = [calendar dateFromComponents:anchorComponents];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"metadata.%K != YES AND %K >= %@ AND %K <= %@",
                              HKMetadataKeyWasUserEntered,
                              HKPredicateKeyPathEndDate, startDate,
                              HKPredicateKeyPathStartDate, endDate];
    // Create the query
    HKStatisticsCollectionQuery *query = [[HKStatisticsCollectionQuery alloc] initWithQuantityType:quantityType
                                                                           quantitySamplePredicate:predicate
                                                                                           options:HKStatisticsOptionCumulativeSum
                                                                                        anchorDate:anchorDate
                                                                                intervalComponents:interval];

    // Set the results handler
    query.initialResultsHandler = ^(HKStatisticsCollectionQuery *query, HKStatisticsCollection *results, NSError *error) {
        if (error) {
            // Perform proper error handling here
            NSLog(@"*** An error occurred while calculating the statistics: %@ ***", error.localizedDescription);
        }

        NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

        [results enumerateStatisticsFromDate:startDate
                                      toDate:endDate
                                   withBlock:^(HKStatistics *result, BOOL *stop) {

                                       HKQuantity *quantity = result.sumQuantity;
                                       if (quantity) {
                                           NSDate *startDate = result.startDate;
                                           NSDate *endDate = result.endDate;
                                           double value = [quantity doubleValueForUnit:unit];

                                           NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:startDate];
                                           NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:endDate];

                                           NSDictionary *elem = @{
                                                   @"value" : @(value),
                                                   @"startDate" : startDateString,
                                                   @"endDate" : endDateString,
                                           };
                                           [data addObject:elem];
                                       }
                                   }];
        // is ascending by default
        if(asc == false) {
            [RCTAppleHealthKit reverseNSMutableArray:data];
        }

        if((lim > 0) && ([data count] > lim)) {
            NSArray* slicedArray = [data subarrayWithRange:NSMakeRange(0, lim)];
            NSError *err;
            completionHandler(slicedArray, err);
        } else {
            NSError *err;
            completionHandler(data, err);
        }
    };

    [self.healthStore executeQuery:query];
}

- (void)fetchCumulativeSumStatisticsCollection:(HKQuantityType *)quantityType
                                          unit:(HKUnit *)unit
                                        period:(NSUInteger)period
                                     startDate:(NSDate *)startDate
                                       endDate:(NSDate *)endDate
                                     ascending:(BOOL)asc
                                         limit:(NSUInteger)lim
                          includeManuallyAdded:(BOOL)includeManuallyAdded
                                    completion:(void (^)(NSArray *, NSError *))completionHandler {

    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *interval = [[NSDateComponents alloc] init];
    interval.minute = period;

    NSDateComponents *anchorComponents = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear
                                                     fromDate:startDate];
    //anchorComponents.hour = 0;
    NSDate *anchorDate = [calendar dateFromComponents:anchorComponents];
    NSPredicate *predicate = nil;
    if (includeManuallyAdded == false) {
        predicate = [NSPredicate predicateWithFormat:@"metadata.%K != YES AND %K >= %@ AND %K <= %@",
                                  HKMetadataKeyWasUserEntered,
                                  HKPredicateKeyPathEndDate, startDate,
                                  HKPredicateKeyPathStartDate, endDate];
    } else {
        predicate = [NSPredicate predicateWithFormat:@"%K >= %@ AND %K <= %@",
                                  HKPredicateKeyPathEndDate, startDate,
                                  HKPredicateKeyPathStartDate, endDate];
    }
    // Create the query
    HKStatisticsCollectionQuery *query = [[HKStatisticsCollectionQuery alloc] initWithQuantityType:quantityType
                                                                           quantitySamplePredicate:predicate
                                                                                           options:HKStatisticsOptionCumulativeSum
                                                                                        anchorDate:anchorDate
                                                                                intervalComponents:interval];

    // Set the results handler
    query.initialResultsHandler = ^(HKStatisticsCollectionQuery *query, HKStatisticsCollection *results, NSError *error) {
        if (error) {
            // Perform proper error handling here
            NSLog(@"*** An error occurred while calculating the statistics: %@ ***", error.localizedDescription);
        }

        NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

        [results enumerateStatisticsFromDate:startDate
                                      toDate:endDate
                                   withBlock:^(HKStatistics *result, BOOL *stop) {

                                       HKQuantity *quantity = result.sumQuantity;
                                       if (quantity) {
                                           NSDate *startDate = result.startDate;
                                           NSDate *endDate = result.endDate;
                                           double value = [quantity doubleValueForUnit:unit];

                                           NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:startDate];
                                           NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:endDate];

                                           NSDictionary *elem = @{
                                                   @"value" : @(value),
                                                   @"startDate" : startDateString,
                                                   @"endDate" : endDateString,
                                           };
                                           [data addObject:elem];
                                       }
                                   }];
        // is ascending by default
        if(asc == false) {
            [RCTAppleHealthKit reverseNSMutableArray:data];
        }

        if((lim > 0) && ([data count] > lim)) {
            NSArray* slicedArray = [data subarrayWithRange:NSMakeRange(0, lim)];
            NSError *err;
            completionHandler(slicedArray, err);
        } else {
            NSError *err;
            completionHandler(data, err);
        }
    };

    [self.healthStore executeQuery:query];
}

 - (void)fetchWorkoutForPredicate:(NSPredicate *)predicate
                        ascending:(BOOL)ascending
                            limit:(NSUInteger)limit
                       completion:(void (^)(NSArray *, NSError *))completion {

    void (^handlerBlock)(HKSampleQuery *query, NSArray *results, NSError *error);
    NSSortDescriptor *endDateSortDescriptor = [[NSSortDescriptor alloc] initWithKey:HKSampleSortIdentifierEndDate ascending:ascending];
    handlerBlock = ^(HKSampleQuery *query, NSArray *results, NSError *error) {
        if(!results) {
            if(completion) {
                completion(nil, error);
            }
            return;
        }

        if(completion) {
            NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];
            NSDictionary *numberToWorkoutNameDictionary = [RCTAppleHealthKit getNumberToWorkoutNameDictionary];

            dispatch_async(dispatch_get_main_queue(), ^{
                for (HKWorkout * sample in results) {
                    double energy = [[sample totalEnergyBurned] doubleValueForUnit:[HKUnit kilocalorieUnit]];
                    double distance = [[sample totalDistance] doubleValueForUnit:[HKUnit mileUnit]];
                    NSNumber *activityNumber =  [NSNumber numberWithInt: [sample workoutActivityType]];

                    NSString *activityName = [numberToWorkoutNameDictionary objectForKey: activityNumber];

                    if (activityName) {
                        NSDictionary *elem = @{
                            @"activityName" : activityName,
                            @"calories" : @(energy),
                            @"distance" : @(distance),
                            @"startDate" : [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate],
                            @"endDate" : [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate]
                        };
                        [data addObject:elem];
                    }
                }
                completion(data, error);
            });

        }
    };

    HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:[HKObjectType workoutType] predicate:predicate limit:limit sortDescriptors:@[endDateSortDescriptor] resultsHandler:handlerBlock];

    [self.healthStore executeQuery:query];
}

/*!
    Set background observer for the given HealthKit sample type. This method should only be called by
    the native code and not injected by any Javascript code, as that might imply in unstable behavior

    @deprecated The setObserver() method has been deprecated in favor of initializeBackgroundObservers()

    @param sampleType The type of samples to add a listener for
    @param type A human readable description for the sample type
 */
- (void)setObserverForType:(HKSampleType *)sampleType
                      type:(NSString *)type __deprecated
{
    HKObserverQuery* query = [
        [HKObserverQuery alloc] initWithSampleType:sampleType
                                         predicate:nil
                                     updateHandler:^(HKObserverQuery* query,
                                                     HKObserverQueryCompletionHandler completionHandler,
                                                     NSError * _Nullable error) {
        NSLog(@"[HealthKit] New sample received from Apple HealthKit - %@", type);

        NSString *successEvent = [NSString stringWithFormat:@"healthKit:%@:sample", type];

        if (error) {
            completionHandler();

            NSLog(@"[HealthKit] An error happened when receiving a new sample - %@", error.localizedDescription);

            return;
        }

        [self sendEventWithName:successEvent body:@{}];

        completionHandler();

        NSLog(@"[HealthKit] New sample from Apple HealthKit processed - %@", type);
    }];


    [self.healthStore enableBackgroundDeliveryForType:sampleType
                                            frequency:HKUpdateFrequencyImmediate
                                       withCompletion:^(BOOL success, NSError * _Nullable error) {
        NSString *successEvent = [NSString stringWithFormat:@"healthKit:%@:enabled", type];

        if (error) {
            NSLog(@"[HealthKit] An error happened when setting up background observer - %@", error.localizedDescription);

            return;
        }

        [self.healthStore executeQuery:query];

        [self sendEventWithName:successEvent body:@{}];
    }];
}

/*!
    Set background observer for the given HealthKit sample type. This method should only be called by
    the native code and not injected by any Javascript code, as that might imply in unstable behavior

    @param sampleType The type of samples to add a listener for
    @param type A human readable description for the sample type
    @param bridge React Native bridge instance
 */
- (void)setObserverForType:(HKSampleType *)sampleType
                      type:(NSString *)type
                    bridge:(RCTBridge *)bridge
                    hasListeners:(bool)hasListeners
{
    HKObserverQuery* query = [
        [HKObserverQuery alloc] initWithSampleType:sampleType
                                         predicate:nil
                                     updateHandler:^(HKObserverQuery* query,
                                                     HKObserverQueryCompletionHandler completionHandler,
                                                     NSError * _Nullable error) {
        NSLog(@"[HealthKit] New sample received from Apple HealthKit - %@", type);

        NSString *successEvent = [NSString stringWithFormat:@"healthKit:%@:new", type];
        NSString *failureEvent = [NSString stringWithFormat:@"healthKit:%@:failure", type];

        if (error) {
            completionHandler();

            NSLog(@"[HealthKit] An error happened when receiving a new sample - %@", error.localizedDescription);
            if(self.hasListeners) {
                [self sendEventWithName:failureEvent body:@{}];
            }
            return;
        }
        if(self.hasListeners) {
            [self sendEventWithName:successEvent body:@{}];
        }
        completionHandler();

        NSLog(@"[HealthKit] New sample from Apple HealthKit processed - %@", type);
    }];


    [self.healthStore enableBackgroundDeliveryForType:sampleType
                                            frequency:HKUpdateFrequencyImmediate
                                       withCompletion:^(BOOL success, NSError * _Nullable error) {
        NSString *successEvent = [NSString stringWithFormat:@"healthKit:%@:setup:success", type];
        NSString *failureEvent = [NSString stringWithFormat:@"healthKit:%@:setup:failure", type];

        if (error) {
            NSLog(@"[HealthKit] An error happened when setting up background observer - %@", error.localizedDescription);
            if(self.hasListeners) {
                [self sendEventWithName:failureEvent body:@{}];
            }
            return;
        }

        [self.healthStore executeQuery:query];
        if(self.hasListeners) {
            [self sendEventWithName:successEvent body:@{}];
        }
        }];
}

- (void)fetchActivitySummary:(NSDate *)startDate
                     endDate:(NSDate *)endDate
                  completion:(void (^)(NSArray *, NSError *))completionHandler
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *startComponent = [calendar components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear | NSCalendarUnitEra
                                                     fromDate:startDate];
    startComponent.calendar = calendar;
    NSDateComponents *endComponent = [calendar components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear | NSCalendarUnitEra
                                                     fromDate:endDate];
    endComponent.calendar = calendar;
    NSPredicate *predicate = [HKQuery predicateForActivitySummariesBetweenStartDateComponents:startComponent endDateComponents:endComponent];
    
    HKActivitySummaryQuery *query = [[HKActivitySummaryQuery alloc] initWithPredicate:predicate
                                        resultsHandler:^(HKActivitySummaryQuery *query, NSArray *results, NSError *error) {
        
        if (error) {
            // Perform proper error handling here
            NSLog(@"*** An error occurred while fetching the summary: %@ ***",error.localizedDescription);
            completionHandler(nil, error);
            return;
        }
        
        NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

        dispatch_async(dispatch_get_main_queue(), ^{
            for (HKActivitySummary *summary in results) {
                int aebVal = [summary.activeEnergyBurned doubleValueForUnit:[HKUnit kilocalorieUnit]];
                int aebgVal = [summary.activeEnergyBurnedGoal doubleValueForUnit:[HKUnit kilocalorieUnit]];
                int aetVal = [summary.appleExerciseTime doubleValueForUnit:[HKUnit minuteUnit]];
                int aetgVal = [summary.appleExerciseTimeGoal doubleValueForUnit:[HKUnit minuteUnit]];
                int ashVal = [summary.appleStandHours doubleValueForUnit:[HKUnit countUnit]];
                int ashgVal = [summary.appleStandHoursGoal doubleValueForUnit:[HKUnit countUnit]];

                NSDictionary *elem = @{
                        @"activeEnergyBurned" : @(aebVal),
                        @"activeEnergyBurnedGoal" : @(aebgVal),
                        @"appleExerciseTime" : @(aetVal),
                        @"appleExerciseTimeGoal" : @(aetgVal),
                        @"appleStandHours" : @(ashVal),
                        @"appleStandHoursGoal" : @(ashgVal),
                };

                [data addObject:elem];
            }

            completionHandler(data, error);
        });
    }];

    [self.healthStore executeQuery:query];
    
}

/*@yulianto.kevin: adding anchored workouts routes*/
- (void)fetchAnchoredMultipleWorkoutRoutes:(HKSampleType *)type
                    predicate:(NSPredicate *)predicate
                       anchor:(HKQueryAnchor *)anchor
                        limit:(NSUInteger)lim
                   completion:(void (^)(NSDictionary *, NSError *))completion {

    // declare the block
    void (^handlerBlock)(HKAnchoredObjectQuery *query, NSArray<__kindof HKSample *> *sampleObjects, NSArray<HKDeletedObject *> *deletedObjects, HKQueryAnchor *newAnchor, NSError *error);

    // create and assign the block
    handlerBlock = ^(HKAnchoredObjectQuery *query, NSArray<__kindof HKSample *> *sampleObjects, NSArray<HKDeletedObject *> *deletedObjects, HKQueryAnchor *newAnchor, NSError *error) {
        // async thread (another thread)

        if (!sampleObjects) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }
    
        // if not completion return
        if (!completion) return;

        NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{  // try to dispatch to another thread
        dispatch_async(dispatch_get_main_queue(), ^{
            for (HKWorkout *sample in sampleObjects) {
                @try {
                    /* Code **/
                    NSPredicate* runningObjectQuery = [HKQuery predicateForObjectsFromWorkout:sample];
                    
                    void (^resultHandlerBlock)(HKAnchoredObjectQuery *query, NSArray<__kindof HKSample *> *sampleWorkoutRoutes, NSArray<HKDeletedObject *> *deletedObjects, HKQueryAnchor *newAnchor, NSError *error);
                    
                    resultHandlerBlock = ^(HKAnchoredObjectQuery *query, NSArray<__kindof HKSample *> *sampleWorkoutRoutes, NSArray<HKDeletedObject *> *deletedObjects, HKQueryAnchor *newAnchor, NSError *error) {
                        if (error) {
                            if (completion) {
                                completion(nil, error);
                            }
                            return;
                        }
                        
                        double energy =  [[sample totalEnergyBurned] doubleValueForUnit:[HKUnit kilocalorieUnit]];
                        double distance = [[sample totalDistance] doubleValueForUnit:[HKUnit mileUnit]];
                        NSString *type = [RCTAppleHealthKit stringForHKWorkoutActivityType:[sample workoutActivityType]];

                        NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate];
                        NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate];

                        bool isTracked = true;
                        if ([[sample metadata][HKMetadataKeyWasUserEntered] intValue] == 1) {
                            isTracked = false;
                        }

                        NSString* device = @"";
                        if (@available(iOS 11.0, *)) {
                            device = [[sample sourceRevision] productType];
                        } else {
                            device = [[sample device] name];
                            if (!device) {
                                device = @"iPhone";
                            }
                        }

                        // Make sure you have some route samples
                        if (sampleWorkoutRoutes != nil && [sampleWorkoutRoutes count] > 0) {
                            //skip workoute route and add empty workoutRoutes
                            NSDictionary *elem = @{
                               @"activityId" : [NSNumber numberWithInt:[sample workoutActivityType]],
                               @"id" : [[sample UUID] UUIDString],
                               @"activityName" : type,
                               @"calories" : @(energy),
                               @"tracked" : @(isTracked),
                               @"metadata" : [sample metadata],
                               @"sourceName" : [[[sample sourceRevision] source] name],
                               @"sourceId" : [[[sample sourceRevision] source] bundleIdentifier],
                               @"device": device,
                               @"distance" : @(distance),
                               @"start" : startDateString,
                               @"end" : endDateString,
                               @"workouteRoutes": [[NSMutableArray alloc] init],
                            };
                            [data addObject:elem];
                            return;
                        }
                        
                        NSDictionary *elem = @{
                           @"activityId" : [NSNumber numberWithInt:[sample workoutActivityType]],
                           @"id" : [[sample UUID] UUIDString],
                           @"activityName" : type,
                           @"calories" : @(energy),
                           @"tracked" : @(isTracked),
                           @"metadata" : [sample metadata],
                           @"sourceName" : [[[sample sourceRevision] source] name],
                           @"sourceId" : [[[sample sourceRevision] source] bundleIdentifier],
                           @"device": device,
                           @"distance" : @(distance),
                           @"start" : startDateString,
                           @"end" : endDateString,
                           @"workouteRoutes": sampleObjects,
                        };
                        
                        [data addObject:elem];
                    };
                    
                    HKAnchoredObjectQuery *routeQuery = [[HKAnchoredObjectQuery alloc] initWithType:[HKSeriesType workoutRouteType] predicate:runningObjectQuery anchor:nil limit:HKObjectQueryNoLimit resultsHandler:resultHandlerBlock];
                    
                    [routeQuery setUpdateHandler:^(HKAnchoredObjectQuery * _Nonnull query, NSArray<__kindof HKSample *> * _Nullable addedObjects, NSArray<HKDeletedObject *> * _Nullable deletedObjects, HKQueryAnchor * _Nullable newAnchor, NSError * _Nullable error) {
                        if (error) return;
                        
                    }];
                    
                    [self.healthStore executeQuery:routeQuery];
                    /* End Code **/
                    
        
                } @catch (NSException *exception) {
                    NSLog(@"RNHealth: An error occured while trying to add workout sample from: %@ ", [[[sample sourceRevision] source] bundleIdentifier]);
                }
            }
            
            // after finish, set the data
            NSData *anchorData = [NSKeyedArchiver archivedDataWithRootObject:newAnchor];
            NSString *anchorString = [anchorData base64EncodedStringWithOptions:0];
            completion(@{
                        @"anchor": anchorString,
                        @"data": data,
                    }, error);
        });
    };

    HKAnchoredObjectQuery *query = [[HKAnchoredObjectQuery alloc] initWithType:type
                                                                     predicate:predicate
                                                                        anchor:anchor
                                                                         limit:lim
                                                                resultsHandler:handlerBlock];

    [self.healthStore executeQuery:query];
}

- (void)fetchAnchoredWorkoutRoutes:(HKWorkout *)sample
                       completion:(void (^)(NSDictionary *, NSError *))completion {
    if (!completion) return;

    NSMutableArray *data = [NSMutableArray arrayWithCapacity:1];

    @try {
        /* Code **/
        NSPredicate* runningObjectQuery = [HKQuery predicateForObjectsFromWorkout:sample];
        
        void (^resultHandlerBlock)(HKAnchoredObjectQuery *query, NSArray<__kindof HKSample *> *sampleWorkoutRoutes, NSArray<HKDeletedObject *> *deletedObjects, HKQueryAnchor *newAnchor, NSError *error);
        
        resultHandlerBlock = ^(HKAnchoredObjectQuery *query, NSArray<__kindof HKSample *> *sampleWorkoutRoutes, NSArray<HKDeletedObject *> *deletedObjects, HKQueryAnchor *newAnchor, NSError *error) {
            if (error) {
                if (completion) {
                    completion(nil, error);
                }
                return;
            }
            
            double energy =  [[sample totalEnergyBurned] doubleValueForUnit:[HKUnit kilocalorieUnit]];
            double distance = [[sample totalDistance] doubleValueForUnit:[HKUnit mileUnit]];
            NSString *type = [RCTAppleHealthKit stringForHKWorkoutActivityType:[sample workoutActivityType]];

            NSString *startDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate];
            NSString *endDateString = [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate];

            bool isTracked = true;
            if ([[sample metadata][HKMetadataKeyWasUserEntered] intValue] == 1) {
                isTracked = false;
            }

            NSString* device = @"";
            if (@available(iOS 11.0, *)) {
                device = [[sample sourceRevision] productType];
            } else {
                device = [[sample device] name];
                if (!device) {
                    device = @"iPhone";
                }
            }

            // Make sure you have some route samples
            if (sampleWorkoutRoutes != nil && [sampleWorkoutRoutes count] > 0) {
                //skip workoute route and add empty workoutRoutes
                NSDictionary *elem = @{
                   @"activityId" : [NSNumber numberWithInt:[sample workoutActivityType]],
                   @"id" : [[sample UUID] UUIDString],
                   @"activityName" : type,
                   @"calories" : @(energy),
                   @"tracked" : @(isTracked),
                   @"metadata" : [sample metadata],
                   @"sourceName" : [[[sample sourceRevision] source] name],
                   @"sourceId" : [[[sample sourceRevision] source] bundleIdentifier],
                   @"device": device,
                   @"distance" : @(distance),
                   @"start" : startDateString,
                   @"end" : endDateString,
                   @"workouteRoutes": [[NSMutableArray alloc] init],
                };
                return;
            }
            
            NSDictionary *elem = @{
               @"activityId" : [NSNumber numberWithInt:[sample workoutActivityType]],
               @"id" : [[sample UUID] UUIDString],
               @"activityName" : type,
               @"calories" : @(energy),
               @"tracked" : @(isTracked),
               @"metadata" : [sample metadata],
               @"sourceName" : [[[sample sourceRevision] source] name],
               @"sourceId" : [[[sample sourceRevision] source] bundleIdentifier],
               @"device": device,
               @"distance" : @(distance),
               @"start" : startDateString,
               @"end" : endDateString,
               @"workouteRoutes": sampleWorkoutRoutes,
            };
        };
        
        HKAnchoredObjectQuery *routeQuery = [[HKAnchoredObjectQuery alloc] initWithType:[HKSeriesType workoutRouteType] predicate:runningObjectQuery anchor:nil limit:HKObjectQueryNoLimit resultsHandler:resultHandlerBlock];
        
        [routeQuery setUpdateHandler:^(HKAnchoredObjectQuery * _Nonnull query, NSArray<__kindof HKSample *> * _Nullable addedObjects, NSArray<HKDeletedObject *> * _Nullable deletedObjects, HKQueryAnchor * _Nullable newAnchor, NSError * _Nullable error) {
            if (error) return;
        }];
        
        [self.healthStore executeQuery:routeQuery];
        /* End Code **/

    } @catch (NSException *exception) {
        NSLog(@"RNHealth: An error occured while trying to add workout sample from: %@ ", [[[sample sourceRevision] source] bundleIdentifier]);
    }
};

- (void)fetchWorkoutRouteLocations:(HKWorkoutRoute *)workoutRoute
                        completion:(void (^)(NSDictionary *, NSError *))completion  API_AVAILABLE(ios(11.0)){

    NSMutableArray *locationData = [NSMutableArray arrayWithCapacity:1];
    
    void (^handlerBlock)(HKWorkoutRouteQuery * _Nonnull query, NSArray<CLLocation *> * _Nullable cllocation, BOOL done, NSError * _Nullable error);
    
    handlerBlock = ^(HKWorkoutRouteQuery * _Nonnull query, NSArray<CLLocation *> * _Nullable cllocation, BOOL done, NSError * _Nullable error)  {
        
        if (error) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }
        
        if (!cllocation) {
            if (completion) {
                NSError *error = [NSError errorWithDomain:@"com.yourcompany.appname" code:3456 userInfo:@{NSLocalizedDescriptionKey:@"No locations found"}];
                completion(nil, error);
            }
            return;
        }
        
        if (completion == nil) return;
        
        [locationData addObjectsFromArray:cllocation];
        
//        NSMutableArray *latitudes = [NSMutableArray arrayWithCapacity:1];
//        NSMutableArray *longitudes = [NSMutableArray arrayWithCapacity:1];
        
//        for (CLLocation *location in cllocation) {
//            // location: altitude, coordinate, course, courseAccuracy, floor, horizontalAccuracy, speed, speedAcuracy
//            [latitudes addObject:[NSNumber numberWithDouble:location.coordinate.latitude]];
//            [longitudes addObject:[NSNumber numberWithDouble:location.coordinate.longitude]];
//        }
        
        // Outline map region to display
//        int maxLat = [[latitudes valueForKeyPath: @"@max.self"] intValue];
//        int minLat = [[latitudes valueForKeyPath: @"@min.self"] intValue];
//        int maxLong = [[longitudes valueForKeyPath: @"@max.self"] intValue];
//        int minLong = [[longitudes valueForKeyPath: @"@min.self"] intValue];

        
        if (done) {
            if (completion) {
                completion(@{
                    @"data": locationData,
                }, error);
            }
            return;
            // The query returned all the location data associated with the route.
            // Do something with the complete data set.
//            let mapDisplayAreaPadding = 1.3
//            let mapCenter = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLong + maxLong) / 2);
//            let mapSpan = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * mapDisplayAreaPadding,
//                                          longitudeDelta: (maxLong - minLong) * mapDisplayAreaPadding)

//            DispatchQueue.main.async {
                // Push to main thread to drop dots on the map.
                // Without this a warning will occur.
//                self.region = MKCoordinateRegion(center: mapCenter, span: mapSpan)
//                locations.forEach { (location) in
//                    self.overlayRoute(at: location)
//                }
//            }
        }
        
        // stop the query by calling:
        // store.stop(query)
    };

    
    HKWorkoutRouteQuery *query = [[HKWorkoutRouteQuery alloc] initWithRoute:workoutRoute dataHandler:handlerBlock];
    [self.healthStore executeQuery:query];
}

/*end @yulianto.kevin*/

@end
