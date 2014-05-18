//
//  CSLabelAnnotationView.h
//  ocua
//
//  Created by michael russell on 11-03-29.
//  Copyright 2011 Thumb Genius Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>


@interface CSLabelAnnotationView : MKAnnotationView {
    UILabel* _label;
}
@property(retain, nonatomic)     UILabel* label;

@end
