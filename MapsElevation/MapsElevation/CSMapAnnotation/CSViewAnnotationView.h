//
//  CSLabelAnnotationView.h
//  ocua
//
//  Created by michael russell on 11-03-29.
//  Copyright 2011 Thumb Genius Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

#define ANNO_OFFSET -15.0f  // half the height of the bubble

@interface CSViewAnnotationView : MKAnnotationView {
    UIView* customView;
}
@property (nonatomic, retain) UIView* customView;
@end
