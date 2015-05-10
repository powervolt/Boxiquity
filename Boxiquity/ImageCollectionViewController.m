//
//  ImageCollectionViewController.m
//  Boxiquity
//
//  Created by Budhathoki,Bipin on 5/8/15.
//  Copyright (c) 2015 Budhathoki,Bipin. All rights reserved.
//

#import "ImageCollectionViewController.h"
#import <DropboxSDK/DropboxSDK.h>
#import "CollectionViewCell.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "UIImage+Extention.h"
#import "ShowImageViewController.h"
#import <CoreLocation/CoreLocation.h>

static NSInteger networkIndicatorVisibleCount;

@interface ImageCollectionViewController () <DBRestClientDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, CLLocationManagerDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *linkAccountButton;
@property (strong, nonatomic) DBRestClient *dbRestClient;
@property (strong, nonatomic) NSMutableArray *photoPaths;
@property (strong, nonatomic) NSString *photosRoot;
@property (strong, nonatomic) UIAlertController *uploadImageActionSheet;
@property (strong, nonatomic) NSMutableArray *uploadingPhotoPaths;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) UIRefreshControl *refreshController;

@end

@implementation ImageCollectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //register cell class
    UINib *nib = [UINib nibWithNibName:kCollectionViewCell bundle:nil];
    [self.collectionView registerNib:nib forCellWithReuseIdentifier:kCollectionViewCell];
    
    //setup action sheet
    [self setupActionSheet];
    
    //setup refresh control
    self.refreshController = [[UIRefreshControl alloc] init];
    self.refreshController.backgroundColor = [UIColor lightGrayColor];
    self.refreshController.tintColor = [UIColor whiteColor];
    [self.refreshController addTarget:self action:@selector(refreshControlTriggered) forControlEvents:UIControlEventValueChanged];
    [self.collectionView addSubview:self.refreshController];
    self.collectionView.alwaysBounceVertical = YES;
    
    
    //setup location manager
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.distanceFilter = kCLDistanceFilterNone;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    
    //setup photo root
    if ([DBSession sharedSession].root == kDBRootDropbox) {
        self.photosRoot = @"/Photos";
    } else {
        self.photosRoot = @"/";
    }
    
    self.uploadingPhotoPaths = [[NSMutableArray alloc] init];
    
    //subscribe to notification if dropbox is linked
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dropBoxLinked:)
                                                 name:@"dropBoxLinked" object:nil];
    
    //check if account is linked
    if (![[DBSession sharedSession] isLinked]) {
        [[DBSession sharedSession] linkFromController:self];
        self.navigationItem.rightBarButtonItem.enabled = NO;
        
    }
    else {
        //setup rest client
        self.dbRestClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        self.dbRestClient.delegate = self;
        
        [self refreshData];
    }
}

-(void)refreshControlTriggered {
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MMM d, h:mm a"];
    NSString *title = [NSString stringWithFormat:@"Last update: %@", [formatter stringFromDate:[NSDate date]]];
    NSDictionary *attrsDictionary = [NSDictionary dictionaryWithObject:[UIColor whiteColor]
                                                                forKey:NSForegroundColorAttributeName];
    NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:attrsDictionary];
    self.refreshController.attributedTitle = attributedTitle;
    
    if([[DBSession sharedSession] isLinked]) {
        [self refreshData];
    }
    
    [self.refreshController endRefreshing];
}

-(void)refreshData {

    self.photoPaths = [[NSMutableArray alloc] init];
    self.navigationItem.rightBarButtonItem.enabled = YES;
    
    self.linkAccountButton.title = @"Unlink Account";
    
    if([[[UIDevice currentDevice] systemVersion] floatValue] > 8.0) {
        [self.locationManager requestWhenInUseAuthorization];
    }
    
    [self.locationManager startUpdatingLocation];

    [self downloadImages];
}

-(void)dropBoxLinked:(NSNotification *)notification{
    //setup rest client with the new session
    self.dbRestClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
    self.dbRestClient.delegate = self;
    self.uploadingPhotoPaths = [[NSMutableArray alloc] init];
    [self refreshData];
}

-(void)setupActionSheet {
    self.uploadImageActionSheet = [UIAlertController alertControllerWithTitle:nil
                                                                      message:nil
                                                               preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    
    __weak ImageCollectionViewController *weakSelf = self;
    UIAlertAction *selectImageAction = [UIAlertAction actionWithTitle:@"Upload from phone"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *action){
                                                                  [weakSelf showImagePickerForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
                                                              }];
    
    UIAlertAction *captureImageAction = [UIAlertAction actionWithTitle:@"Upload from camera"
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction *action){
                                                                   [weakSelf showImagePickerForSourceType:UIImagePickerControllerSourceTypeCamera];
                                                               }];
    
    [self.uploadImageActionSheet addAction:cancelAction];
    [self.uploadImageActionSheet addAction:selectImageAction];
    [self.uploadImageActionSheet addAction:captureImageAction];
}

-(void)showEmptyDataLabel {
    UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
    
    if([[DBSession sharedSession] isLinked]) {
        messageLabel.text = @"No Photos Available.";
    }
    else {
        messageLabel.text = @"DropBox account not linked.";
    }
    messageLabel.textColor = [UIColor blackColor];
    messageLabel.numberOfLines = 0;
    messageLabel.textAlignment = NSTextAlignmentCenter;
    messageLabel.font = [UIFont fontWithName:@"Helvetica Neue" size:20];
    [messageLabel sizeToFit];
    
    self.collectionView.backgroundView = messageLabel;
}

#pragma mark Helper Methods

-(void)updateNavigationTitle {
    [self.navigationItem setTitle:[NSString stringWithFormat:@"Photos (%lu)",(unsigned long)self.photoPaths.count]];
}

-(void)setNetworkActivityIndicatorVisible:(BOOL)visible {
    if(visible){
        networkIndicatorVisibleCount++;
    }
    else if(networkIndicatorVisibleCount > 0) {
        networkIndicatorVisibleCount--;
    }
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:(networkIndicatorVisibleCount > 0)];
}

#pragma mark Download and Upload helper
- (void)downloadImages {
    [self setNetworkActivityIndicatorVisible:YES];
    [self.dbRestClient loadMetadata:self.photosRoot];
}

- (void)uploadImage:(UIImage *)image {
    [self setNetworkActivityIndicatorVisible:YES];
    
    NSString *filename = [NSString stringWithFormat:@"%@_Photo.%@", [[NSUUID UUID] UUIDString],[image contextType]];
    NSData *imageData = UIImagePNGRepresentation(image);
    
    NSString *localDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *localPath = [localDir stringByAppendingPathComponent:filename];
    
    NSError *error;
    [imageData writeToFile:localPath options:NSDataWritingAtomic error:&error];
    
    if(!error) {
        [self.dbRestClient uploadFile:filename toPath:self.photosRoot withParentRev:nil fromPath:localPath];
        
        [self.uploadingPhotoPaths addObject:localPath];
        [self.collectionView reloadData];
        
        //scroll to the lastindex
        NSIndexPath *lastIndex = [NSIndexPath indexPathForRow:[self.collectionView numberOfItemsInSection:0] - 1 inSection:0];
        if(lastIndex.row > 0) {
            [self.collectionView scrollToItemAtIndexPath:lastIndex atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:YES];
        }
        
    }
    else {
        [self setNetworkActivityIndicatorVisible:NO];
        NSLog(@"Failed to write to file");
    }
}

#pragma mark Navigation Button Action

- (IBAction)uploadImageButtonTapped:(id)sender {
    [self presentViewController:self.uploadImageActionSheet
                       animated:YES
                     completion:nil];
}
- (IBAction)unlinkAccountButtonTapped:(id)sender {
    if([[DBSession sharedSession] isLinked]){
        [[DBSession sharedSession] unlinkAll];
        
        self.linkAccountButton.title = @"Link Account";
        
        self.photoPaths = nil;
        self.uploadingPhotoPaths = nil;
        [self.collectionView reloadData];
        self.navigationItem.title = @"DropBox";
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }
    else {
        //link the account
        [[DBSession sharedSession] linkFromController:self];
    }
}

#pragma mark <CLLocationManagerDelegate>

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    CLLocation *lastLocation = [locations lastObject];
    NSLog(@"NewLocation %f %f", lastLocation.coordinate.latitude, lastLocation.coordinate.longitude);
}

#pragma  mark ImagePicker Helper

- (void)showImagePickerForSourceType:(UIImagePickerControllerSourceType)sourceType {
    if(sourceType == UIImagePickerControllerSourceTypeCamera && ![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] ){
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Warning"
                                                                                 message:@"No camera found for this device"
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        
        [alertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alertController animated:YES completion:nil];
        return;
    }
    
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.modalPresentationStyle = UIModalPresentationCurrentContext;
    imagePickerController.sourceType = sourceType;
    imagePickerController.delegate = self;
    imagePickerController.mediaTypes = @[(NSString *)kUTTypeImage];
    imagePickerController.allowsEditing = YES;
    
    [self presentViewController:imagePickerController animated:YES completion:nil];
}


#pragma mark <UIImagePickerControllerDelegate>

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage* image = info[UIImagePickerControllerEditedImage];
    
    if(!image){
        image = info[UIImagePickerControllerOriginalImage];
    }
    
    [self uploadImage:image];
    [picker dismissViewControllerAnimated:YES completion:nil];
}

-(void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSInteger count = self.photoPaths.count + self.uploadingPhotoPaths.count;
    
    if(count <= 0) {
        [self showEmptyDataLabel];
    }
    else {
        self.collectionView.backgroundView = nil;
    }
    
    return count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    CollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kCollectionViewCell forIndexPath:indexPath];
    
    if(indexPath.row < self.photoPaths.count) {
        DBMetadata *dbMetaData = self.photoPaths[indexPath.row];
        NSString *localPath = [NSTemporaryDirectory() stringByAppendingPathComponent:dbMetaData.filename];
        
        //check if the file exists
        if([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
            cell.imageView.image = [UIImage imageWithContentsOfFile:localPath];
            [cell.activityIndicator stopAnimating];
        }
        
        else{
            if (dbMetaData.thumbnailExists) {
                [self.dbRestClient loadThumbnail:dbMetaData.path ofSize:@"iphone_bestfit" intoPath:localPath];
                [cell.activityIndicator startAnimating];
                [self setNetworkActivityIndicatorVisible:YES];
            }
            else {
                [self.dbRestClient loadFile:dbMetaData.path intoPath:localPath];
                [cell.activityIndicator startAnimating];
                [self setNetworkActivityIndicatorVisible:YES];
                
            }
        }
    }
    else { //image is uploding
        cell.imageView.image = nil;
        [cell.activityIndicator startAnimating];
        
    }
    
    return cell;
}

#pragma mark <UICollectionViewDelegate>

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(110, 110);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(10,12,10,12);  // top, left, bottom, right
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    CollectionViewCell *cell = (CollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    cell.imageView.alpha = 0.5;
}
- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    CollectionViewCell *cell = (CollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    cell.imageView.alpha = 1.0;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    //check if uploding image was selected
    if(indexPath.row > self.photoPaths.count-1) {
        return;
    }
    
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    ShowImageViewController *viewController = [storyBoard instantiateViewControllerWithIdentifier:@"showImageViewController"];
    viewController.photosPath = [self.photoPaths mutableCopy];
    viewController.selectedIndex = indexPath.row;
    
    [self.navigationController pushViewController:viewController animated:YES];
}

#pragma mark <DBRestClientDelegate>

- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata {
    if(metadata.isDirectory){
        NSArray* validExtensions = [NSArray arrayWithObjects:@"jpg", @"jpeg", @"png", @"gif" ,@"raw", nil];
        for (DBMetadata *data in metadata.contents){
            NSString* extension = [[data.path pathExtension] lowercaseString];
            if (!data.isDirectory && [validExtensions indexOfObject:extension] != NSNotFound) {
                [self.photoPaths addObject:data];
            }
        }
        
        if (self.photoPaths.count > 0) {
            NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"lastModifiedDate" ascending:YES];
            [self.photoPaths sortUsingDescriptors:[NSArray arrayWithObjects:descriptor,nil]];
        }
    }
    
    [self updateNavigationTitle];
    [self.collectionView reloadData];
    [self setNetworkActivityIndicatorVisible:NO];
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error {
    NSLog(@"Failed to load images");
    
    UIAlertController *alertController =[UIAlertController alertControllerWithTitle:@"Network Error"
                                                                            message:@"Failed to load images"
                                                                     preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    [alertController addAction:cancelAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
    
    [self setNetworkActivityIndicatorVisible:NO];
}

-(void)restClient:(DBRestClient *)client loadedFile:(NSString *)destPath {
    [self.collectionView reloadData];
    [self setNetworkActivityIndicatorVisible:NO];
}

- (void)restClient:(DBRestClient*)client loadedThumbnail:(NSString*)destPath metadata:(DBMetadata*)metadata {
    [self.collectionView reloadData];
    [self setNetworkActivityIndicatorVisible:NO];
}

- (void)restClient:(DBRestClient*)client loadThumbnailFailedWithError:(NSError*)error {
    NSLog(@"Failed to load thumbnail image");
    [self setNetworkActivityIndicatorVisible:NO];
    
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error {
    NSLog(@"Failed to load image");
    [self setNetworkActivityIndicatorVisible:NO];
}

- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)destPath
              from:(NSString *)srcPath metadata:(DBMetadata *)metadata {
    NSLog(@"File uploaded successfully to path: %@", metadata.path);
    
    //only update if linked.
    if([[DBSession sharedSession] isLinked]) {
        @synchronized(self.uploadingPhotoPaths) {
            for(NSString *path in self.uploadingPhotoPaths) {
                if([path isEqualToString:srcPath]){
                    [self.uploadingPhotoPaths removeObject:path];
                    break;
                }
            }
        }
        [self.photoPaths addObject:metadata];
        [self.collectionView reloadData];
        [self updateNavigationTitle];
    }
    
    [self setNetworkActivityIndicatorVisible:NO];
}

- (void)restClient:(DBRestClient *)client uploadFileFailedWithError:(NSError *)error {
    NSLog(@"File upload failed with error: %@", error);
    
    //only update if linked.
    if([[DBSession sharedSession] isLinked]) {
        @synchronized(self.uploadingPhotoPaths) {
            NSDictionary *userInfo = [error userInfo];
            NSString *srcPath = [userInfo objectForKey:@"sourcePath"];
            for(NSString *path in self.uploadingPhotoPaths) {
                if([path isEqualToString:srcPath]){
                    [self.uploadingPhotoPaths removeObject:path];
                    break;
                }
            }
        }
        [self.collectionView reloadData];
        [self updateNavigationTitle];
    }
    
    [self setNetworkActivityIndicatorVisible:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
