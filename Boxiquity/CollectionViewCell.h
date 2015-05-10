//
//  CollectionViewCell.h
//  Boxiquity
//
//  Created by Budhathoki,Bipin on 5/8/15.
//  Copyright (c) 2015 Budhathoki,Bipin. All rights reserved.
//

#import <UIKit/UIKit.h>

FOUNDATION_EXTERN NSString *const kCollectionViewCell;

@interface CollectionViewCell : UICollectionViewCell

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@end
