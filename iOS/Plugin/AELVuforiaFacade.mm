//
//  Vuforia Plugin for Cordova
//  
//  Copyright Georgia Institute of Technology
//  Augmented Envionments Lab
//  
//  All Rights Reserved
//
//  Refer to LICENSE.txt file for software license information
//

#import "AELVuforiaFacade.h"
#import "NSURL+FileSystem.h"

#import <QCAR/CameraDevice.h>
#import <QCAR/ImageTracker.h>
#import <QCAR/MarkerTracker.h>
#import <QCAR/QCAR.h>
#import <QCAR/QCAR_iOS.h>
#import <QCAR/Renderer.h>
#import <QCAR/TrackerManager.h>
#import <QCAR/VideoBackgroundConfig.h>

@interface AELVuforiaFacade ()

-(void)initialize;
-(NSInteger)initQCAR;
-(NSDictionary *)startCamera;
-(void)configureCamera;
-(void)initTrackers;

@end

static AELVuforiaFacade *vuforia = nil;

@implementation AELVuforiaFacade

@synthesize viewSize;
@synthesize videoMode = _videoMode;
@synthesize focusMode = _focusMode;
@synthesize cameraTorchMode = _cameraTorchMode;
@synthesize cacheDirectory = _cacheDirectory;
@synthesize delegate = _delegate;

- (id) init {
    
    if (self = [super init])
    {
        vuforia_queue = dispatch_queue_create("vuforia_queue", DISPATCH_QUEUE_SERIAL);
        
        qcarInitFlags   = QCAR::GL_20;
        
        qcarRenderFlags = QCAR::ROTATE_IOS_90;

        self.videoMode          = VuforiaVideoModeDefault;
        self.focusMode          = VuforiaCameraFocusModeAutoContinuous;
        self.cameraTorchMode    = YES;
        
        self.viewSize   = [[UIScreen mainScreen] bounds].size;
    }
    
    return self;
}

+(AELVuforiaFacade *)sharedInstance {
    
    if (vuforia == nil)
    {
        vuforia = [[AELVuforiaFacade alloc] init];
    }

    return vuforia;
}

- (void)initialize {
    
    dispatch_async(vuforia_queue, ^{
        [self initQCARParameters];
        
        NSInteger result;
        result = [self initQCAR];
        
        [self notifyDelegateOfInitializationResult: result];
    });
    
    dispatch_async(vuforia_queue, ^{
        [self initTrackers];
    });    
    
    dispatch_async(vuforia_queue, ^{
        NSDictionary *cameraCalibration;
        cameraCalibration = [self startCamera];
        
        [self configureCamera];
        
        [self notifyDelegateCameraStarted: cameraCalibration];        
    });
    
}

-(void)initQCARParameters {
    QCAR::setInitParameters(qcarInitFlags);
    QCAR::setInitParameters(qcarRenderFlags);  
}

-(NSInteger)initQCAR
{
    // QCAR::init() will return positive numbers up to 100 as it progresses towards success
    // and negative numbers for error indicators
    NSInteger initSuccess = 0;
    do {
        initSuccess = QCAR::init();
    } while (0 <= initSuccess && 100 > initSuccess);    

    return initSuccess;
}

#pragma mark -
#pragma mark Trackers

//############################################################################//
//                             
//                              Trackers                                        
//
//############################################################################//

-(void)initTrackers {
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    imageTracker    = (QCAR::ImageTracker *)trackerManager.initTracker(QCAR::Tracker::IMAGE_TRACKER);
    markerTracker   = (QCAR::MarkerTracker *)trackerManager.initTracker(QCAR::Tracker::MARKER_TRACKER);
}

- (QCAR::Tracker *)getTargetTracker:(VuforiaTrackerType)trackerType {
    QCAR::Tracker *target = nil;
    if (trackerType == VuforiaTrackerImage)
    {
        target = imageTracker;
    }
    
    if (trackerType == VuforiaTrackerMarker)
    {
        target = markerTracker;
    }    

    return target;
}

- (void)startTracker:(VuforiaTrackerType)trackerType {
    QCAR::Tracker* tracker;
    tracker = [self getTargetTracker: trackerType];
    tracker->start();
}

- (void)stopTracker:(VuforiaTrackerType)trackerType {
    QCAR::Tracker* tracker;
    tracker = [self getTargetTracker: trackerType];
    tracker->stop();
}

/******************************************************************************/
/*                            Data                                            */
/******************************************************************************/

- (void)downloadDataSetFromURL:(NSURL *)dataSetURL {
    if (network_queue == nil)
    {
        network_queue = [[NSOperationQueue alloc] init];
        [network_queue setName: @"DownloadQueue"];
    }
    
    NSURLRequest *request;
    
    request = [NSURLRequest requestWithURL: dataSetURL cachePolicy: NSURLCacheStorageAllowed timeoutInterval: 15];
    
    void (^downloadHandler)(NSURLResponse *, NSData *, NSError *) = ^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil)
        {
            // TODO : handle download error
        }
        
        else 
        {
            NSURL *fileURL;
            NSError *writeError = nil;
            
            fileURL = [self.cacheDirectory URLByAppendingPathComponent: [dataSetURL fileSystemEscapedString]];
            
            [data writeToURL: fileURL options: NSDataWritingAtomic error: &writeError];
            
            if (writeError != nil)
            {
                // TODO : handle write error
            } 
        }
    };
    
    [NSURLConnection sendAsynchronousRequest: request 
                                       queue: network_queue 
                           completionHandler: downloadHandler];    
}





/******************************************************************************/
/*                      Camera and Video Background                           */
/******************************************************************************/

-(NSDictionary *)startCamera {

    QCAR::CameraDevice* cameraDevice;
    cameraDevice = &QCAR::CameraDevice::getInstance();
    
    NSDictionary *cameraCalibration = nil;
    
    if (cameraDevice->init()) {
        // Configure video background
        [self configureVideoBackground];
        
        cameraDevice->selectVideoMode(self.videoMode);
        
        // Start camera capturing
        if (cameraDevice->start()) {                      
            const QCAR::CameraCalibration& cal = cameraDevice->getCameraCalibration();
            
            QCAR::Vec2F camSize;
            QCAR::Vec2F camFocalLength;
            
            camSize         = cal.getSize();
            camFocalLength  = cal.getFocalLength();
            
            NSNumber *focalLengthVertical, *focalLengthHorizontal, *frameSizeVertical, *frameSizeHorizontal;
            
            focalLengthVertical     = [NSNumber numberWithFloat: camFocalLength.data[0]];
            focalLengthHorizontal   = [NSNumber numberWithFloat: camFocalLength.data[1]];
            frameSizeVertical       = [NSNumber numberWithFloat: camSize.data[0]];
            frameSizeHorizontal     = [NSNumber numberWithFloat: camSize.data[1]];
            
           cameraCalibration = [NSDictionary dictionaryWithObjectsAndKeys: 
                               focalLengthVertical, @"focalLengthVertical",
                               focalLengthHorizontal, @"focalLengthHorizontal", 
                               frameSizeVertical, @"frameSizeVertical", 
                               frameSizeHorizontal, @"frameSizeHorizontal", nil];
        }
    }
    
    return cameraCalibration;
}

-(void)stopCamera {
    QCAR::CameraDevice* cameraDevice;
    cameraDevice = &QCAR::CameraDevice::getInstance();
    cameraDevice->stop();
    cameraDevice->deinit();
}

- (void)configureCamera
{
    QCAR::CameraDevice* cameraDevice;
    cameraDevice = &QCAR::CameraDevice::getInstance();
    cameraDevice->setFocusMode(self.focusMode);
    cameraDevice->setFlashTorchMode(self.cameraTorchMode);
}

- (void)setCameraFocusMode:(VuforiaCameraFocusMode)focusMode {
    self.focusMode = focusMode;
    QCAR::CameraDevice* cameraDevice;
    cameraDevice = &QCAR::CameraDevice::getInstance();
    cameraDevice->setFocusMode(self.focusMode);
}

- (void)setCameraTorch:(BOOL)torchOn {
    self.cameraTorchMode = torchOn;
    QCAR::CameraDevice* cameraDevice;
    cameraDevice = &QCAR::CameraDevice::getInstance();
    cameraDevice->setFlashTorchMode(self.cameraTorchMode);
}

// Configure the video background
- (void)configureVideoBackground
{
    // Get the default video mode
    QCAR::CameraDevice& cameraDevice = QCAR::CameraDevice::getInstance();
    QCAR::VideoMode videoMode = cameraDevice.getVideoMode(QCAR::CameraDevice::MODE_DEFAULT);
    
    // Configure the video background
    QCAR::VideoBackgroundConfig config;
    config.mEnabled = true;
    config.mSynchronous = true;
    config.mPosition.data[0] = 0.0f;
    config.mPosition.data[1] = 0.0f;
    
    // Compare aspect ratios of video and screen.  If they are different
    // we use the full screen size while maintaining the video's aspect
    // ratio, which naturally entails some cropping of the video.
    // Note - screenRect is portrait but videoMode is always landscape,
    // which is why "width" and "height" appear to be reversed.
    float arVideo = (float)videoMode.mWidth / (float)videoMode.mHeight;
    float arScreen = viewSize.height / viewSize.width;
    
    int width;
    int height;
    
    if (arVideo > arScreen)
    {
        // Video mode is wider than the screen.  We'll crop the left and right edges of the video
        config.mSize.data[0] = (int)viewSize.width * arVideo;
        config.mSize.data[1] = (int)viewSize.width;
        width = (int)viewSize.width;
        height = (int)viewSize.height;
    }
    else
    {
        // Video mode is taller than the screen.  We'll crop the top and bottom edges of the video.
        // Also used when aspect ratios match (no cropping).
        config.mSize.data[0] = (int)viewSize.height;
        config.mSize.data[1] = (int)viewSize.height / arVideo;
        width = (int)viewSize.height;
        height = (int)viewSize.width;
    }
    
    // Calculate the viewport for the app to use when rendering.  This may or
    // may not be used, depending on the desired functionality of the app
    viewport.origin.x = ((width - config.mSize.data[0]) / 2) + config.mPosition.data[0];
    viewport.origin.y =  (((int)(height - config.mSize.data[1])) / (int) 2) + config.mPosition.data[1];
    viewport.size.width = config.mSize.data[0];
    viewport.size.height = config.mSize.data[1];
    
    // Set the config
    QCAR::Renderer::getInstance().setVideoBackgroundConfig(config);
}


/******************************************************************************/
/*                      Delegate Notification                                 */
/******************************************************************************/

/*
 * @param NSInteger result : status of QCAR init (negative->error, 100->finished)
 */
-(void)notifyDelegateOfInitializationResult:(NSInteger)result {
    if (result < 0) {
        SEL errorSelector = @selector(vuforiaInitializationFailedWithError:);
        if ([self.delegate respondsToSelector: errorSelector])
        {
            [self.delegate performSelector: @selector(vuforiaInitializationFailedWithError:)
                                withObject: [NSNumber numberWithInteger: result]];
        }
    }
    
    if (result == 100) {
        SEL successSelector = @selector(vuforiaInitialized);
        if ([self.delegate respondsToSelector: successSelector])
        {
            [self.delegate performSelector: @selector(vuforiaInitialized)];
        }
    }
}

/*
 *@param NSDictionary *cameraInfo : contains camera calibration data
 */
-(void)notifyDelegateCameraStarted:(NSDictionary *)cameraInfo {
    if ([self.delegate respondsToSelector: @selector(vuforiaCameraStarted:)])
    {
        [self.delegate performSelector: @selector(vuforiaCameraStarted:) 
                            withObject: cameraInfo];
    }
    
}



@end
