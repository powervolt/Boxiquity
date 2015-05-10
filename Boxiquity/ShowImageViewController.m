//
//  ShowImageViewController.m
//  Boxiquity
//
//  Created by Budhathoki,Bipin on 5/9/15.
//  Copyright (c) 2015 Budhathoki,Bipin. All rights reserved.
//

#import "ShowImageViewController.h"
#import <DropboxSDK/DropboxSDK.h>


@interface ShowImageViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) UIImageView *tempImageView;
@property (strong, nonatomic) UITapGestureRecognizer *tapGestureRecognizer;
@property (strong, nonatomic) UIPanGestureRecognizer *panGestureRecognizer;
@property (strong, nonatomic) UIPinchGestureRecognizer *pinchGestureRecognizer;
@property (nonatomic) BOOL isFullScreen;
@property (nonatomic) CGRect prevFrame; //store previous frame for full screen mode
@property (nonatomic) CGFloat currentScale;

@end

@implementation ShowImageViewController

-(void)viewDidLoad {
    
    self.isFullScreen = NO;
    
    DBMetadata *dbMetaData = self.photosPath[self.selectedIndex];
    NSString *localPath = [NSTemporaryDirectory() stringByAppendingPathComponent:dbMetaData.filename];
    
    if([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        self.imageView.image = [UIImage imageWithContentsOfFile:localPath];
    }
    
    self.panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(imageSwiped:)];
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(screenTapped)];
    [self.imageView addGestureRecognizer:self.tapGestureRecognizer];
    [self.imageView addGestureRecognizer:self.panGestureRecognizer];
    [self.imageView setUserInteractionEnabled:YES];
    
    self.currentScale = self.imageView.frame.size.width / self.imageView.bounds.size.width;
    
    [self updateNavigationTitle];
    
}

-(void)updateNavigationTitle {
    self.navigationItem.title = [NSString stringWithFormat:@"%lu of %lu",(unsigned long)self.selectedIndex + 1, (unsigned long)self.photosPath.count];
}

-(void)screenTapped {
    if (!self.isFullScreen) {
        self.imageView.backgroundColor = [UIColor blackColor];
        self.view.backgroundColor = [UIColor blackColor];
        self.navigationController.navigationBar.hidden = YES;
        
        [UIView animateWithDuration:0.5 delay:0 options:0 animations:^{
            //save previous frame
            self.prevFrame = self.imageView.frame;
            [self.imageView setFrame:[[UIScreen mainScreen] bounds]];
        }completion:^(BOOL finished){
            self.isFullScreen = true;
        }];
        return;
    } else {
        self.imageView.backgroundColor = [UIColor whiteColor];
        self.view.backgroundColor = [UIColor whiteColor];
        self.navigationController.navigationBar.hidden = NO;
        
        [UIView animateWithDuration:0.5 delay:0 options:0 animations:^{
            [self.imageView setFrame:self.prevFrame];
        }completion:^(BOOL finished){
            self.isFullScreen = false;
        }];
        return;
    }
}

-(void)imageSwiped:(UIPanGestureRecognizer *)gestureRecognizer {
    static CGFloat currentImageWidth;
    
    static CGPoint originalCenter;
    static CGPoint originalCenter2;
    
    static BOOL isSwipeAble = true;
    
    static CGPoint velocity;
    static BOOL isRightSwipe;
    
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    CGFloat width = screenSize.width + 10; // +10 for border
    
    //get the velocity to ditect left or right swipe
    if(gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        
        currentImageWidth = self.imageView.bounds.size.width;;
        
        originalCenter = [gestureRecognizer view].center;
        
        
        velocity = [gestureRecognizer velocityInView:self.imageView];
        if(velocity.x >= 0){
            originalCenter2 = CGPointMake(-originalCenter.x - 10, originalCenter.y);
            isRightSwipe = true;
        }
        else{
            originalCenter2 = CGPointMake(originalCenter.x + width, originalCenter.y);
            isRightSwipe = false;
        }
        
        if(isRightSwipe && self.selectedIndex <= 0) {
            isSwipeAble = false;
        }
        else if(!isRightSwipe && self.selectedIndex >= self.photosPath.count - 1) {
            isSwipeAble = false;
        }
        
        else {
            isSwipeAble = true;
        }
        
        if(isSwipeAble) {
            self.tempImageView = [[UIImageView alloc] initWithFrame:self.imageView.frame];
            
            [self.tempImageView setContentMode:UIViewContentModeScaleAspectFit];
            
            if(isRightSwipe) {
                self.selectedIndex --;
            }
            else {
                self.selectedIndex ++;
            }
            
            DBMetadata *dbMetaData = self.photosPath[self.selectedIndex];
            NSString *localPath = [NSTemporaryDirectory() stringByAppendingPathComponent:dbMetaData.filename];
            
            //if found show the image else show the activity indicator
            
            if([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
                [self.tempImageView setImage:[UIImage imageWithContentsOfFile:localPath]];
            }
            else {
                [self.tempImageView setImage:[UIImage imageNamed:@"loading.png"]];
            }
            [self.tempImageView setCenter:originalCenter2];
            [self.view addSubview:self.tempImageView];
        }
    }
    
    else if(gestureRecognizer.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [gestureRecognizer translationInView:self.imageView];
        gestureRecognizer.view.center = CGPointMake(originalCenter.x + translation.x, originalCenter.y);
        
        if (isSwipeAble) {
            self.tempImageView.center = CGPointMake(originalCenter2.x + translation.x, originalCenter2.y);
            
            //check for 30% width swiped;
            int percentage = (translation.x * 100)/currentImageWidth;
            
            if(abs(percentage) > 30) {
                self.panGestureRecognizer.enabled = false;
                
                [UIView animateWithDuration:0.3 animations:^{
                    if(isRightSwipe) {
                        self.imageView.center = CGPointMake(originalCenter.x+ width, originalCenter.y);
                    }
                    else {
                        self.imageView.center = CGPointMake(-originalCenter.x, originalCenter.y);
                    }
                    self.tempImageView.center = originalCenter;
                    
                } completion:^(BOOL finished){
                    if(finished == YES) {
                        [self.imageView setImage:self.tempImageView.image];
                        [self.imageView setCenter:originalCenter];
                        [self.tempImageView removeFromSuperview];
                        self.tempImageView = nil;
                        [self.view bringSubviewToFront:self.imageView];
                        self.panGestureRecognizer.enabled = YES;
                        [self updateNavigationTitle];
                    }
                }];
            }
        }
    }
    
    else if(gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        //ended without suceess
        if(gestureRecognizer.enabled == YES) {
            [UIView animateWithDuration:0.3 animations:^{
                self.imageView.center = originalCenter;
                self.tempImageView.center = originalCenter2;
            } completion:^(BOOL finished){
                [self.tempImageView removeFromSuperview];
                self.tempImageView = nil;
            }];
            
            //rectify the count since we new image was not shown
            if(isSwipeAble & isRightSwipe) {
                self.selectedIndex ++;
            }
            else if(isSwipeAble & !isRightSwipe) {
                self.selectedIndex --;
            }
        }
    }
}

@end
