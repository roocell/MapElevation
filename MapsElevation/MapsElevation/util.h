/*
 *  util.h
 *
 *  Created by michael russell on 10-11-15.
 *  Copyright 2010 Thumb Genius Software. All rights reserved.
 *
 */
#define APP_VERSION         ([[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"])
#define APP_VERSION_BUILD   ([[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"])
#define APP_BUNDLE_ID       ([[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"])


#define TGLog(message, ...) NSLog(@"%s:%d %@", __FUNCTION__, __LINE__, [NSString stringWithFormat:message, ##__VA_ARGS__])
#define TGMark    TGLog(@"");


#define RGB(r, g, b) [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1]

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

#define PI 3.14159265
#define EARTH_RADIUS_M 6378100
float deg2rad(float val);
float rad2deg(float rad);
float getDist(float lat1, float long1, float lat2, float long2);
float getBearing(float startLat,float startLong,float endLat,float endLong);

// APP OPTIONS
#define MAP_ZOOM_LIMIT              3500    // meters
#define WAY_QUERY_LIMIT             500     // number of ways returned - dont want to perform calculations (too much processing)
#define WAY_DISTANCE                250.0   // meters
#define SLOPE_CHANGE_EVAL_DIST      10.0    // meters
#define MIN_WAY_DIST_TO_DISPLAY     50.0

#define SLOPE_BLACK                 25.0
#define SLOPE_PURPLE                20.0
#define SLOPE_RED                   15.0
#define SLOPE_ORANGE                10.0
#define SLOPE_YELLOW                7.0
#define SLOPE_GREEN                 4.0
#define SLOPE_BLUE                  1.0
#define MIN_SLOPE_DISPLAYED         SLOPE_BLUE     // will not display roads with slope lower than this

