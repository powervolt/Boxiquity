//
//  UIImage+Extention.m
//  Boxiquity
//
//  Created by Budhathoki,Bipin on 5/8/15.
//  Copyright (c) 2015 Budhathoki,Bipin. All rights reserved.
//

#import "UIImage+Extention.h"

@implementation UIImage (Extention)

- (NSString *)contextType {
    NSData *imageData = UIImagePNGRepresentation(self);
    uint8_t c;
    [imageData getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return @"jpeg";
        case 0x89:
            return @"png";
        case 0x47:
            return @"gif";
        case 0x49:
            break;
        case 0x42:
            return @"bmp";
        case 0x4D:
            return @"tiff";
    }
    return nil;
}

@end
