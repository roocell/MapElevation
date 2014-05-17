//
//  util.c
//  MapsElevation
//
//  Created by michael russell on 2014-05-17.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#include <stdio.h>
#include "util.h"
#include <math.h> 

float deg2rad(float val)
{
	return val*PI/180;
}
float rad2deg(float rad)
{
	return rad*180/PI;
}
float getDist(float lat1, float long1, float lat2, float long2)
{
	// haversine formula
	float dlat= lat1-lat2;
	float dlong= long1-long2;
	float a=pow( sin(deg2rad(dlat)/2) ,2) + cos(deg2rad (lat1)) * cos(deg2rad(lat2)) * pow(sin(deg2rad(dlong)/2),2);
	float c=2*atan2(sqrt(a), sqrt(1-a));
	float dist=EARTH_RADIUS_M*c;
	return dist;
}

float getBearing(float lat1,float lat2,float lng1,float lng2)
{
    float dlng=deg2rad(lng2-lng1);
    float bearing=rad2deg(atan2(
                                sin(dlng)*cos(lat2),
                                cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(dlng)
                                ));
    bearing=fmodf(bearing+360.0, 360.0);
    return bearing;
}