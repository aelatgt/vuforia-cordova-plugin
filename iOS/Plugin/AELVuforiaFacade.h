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

#import <Foundation/Foundation.h>

#import <QCAR/CameraDevice.h>
#import <QCAR/QCAR.h>
#import <QCAR/QCAR_iOS.h>
#import <QCAR/Tracker.h>

@protocol AELVuforiaDelegate <NSObject>

-(void)vuforiaInitialized;
-(void)vuforiaInitializationFailedWithError:(NSInteger)errorCode;
-(void)vuforiaImageTrackerInitialized;
-(void)vuforiaMarkerTrackerInitailized;
-(void)vuforiaCameraStarted:(NSDictionary *)cameraInfo;

@end

enum VuforiaVideoMode {
    VuforiaVideoModeDefault         = QCAR::CameraDevice::MODE_DEFAULT,
    VuforiaVideoModeOptimizeSpeed   = QCAR::CameraDevice::MODE_OPTIMIZE_SPEED,
    VuforiaVideoModeOptimizeQuality = QCAR::CameraDevice::MODE_OPTIMIZE_QUALITY
};

enum VuforiaCameraFocusMode {
    VuforiaCameraFocusModeAutoContinuous = QCAR::CameraDevice::FOCUS_MODE_CONTINUOUSAUTO,
    VuforiaCameraFocusModeInfinity       = QCAR::CameraDevice::FOCUS_MODE_INFINITY,
    VuforiaCameraFocusModeAutoTrigger    = QCAR::CameraDevice::FOCUS_MODE_TRIGGERAUTO,
    VuforiaCameraFocusModeMacro          = QCAR::CameraDevice::FOCUS_MODE_MACRO,
    VuforiaCameraFocusModeNormal         = QCAR::CameraDevice::FOCUS_MODE_NORMAL
};

enum VuforiaTrackerType {
    VuforiaTrackerImage     = QCAR::Tracker::IMAGE_TRACKER,
    VuforiaTrackerMarker    = QCAR::Tracker::MARKER_TRACKER
};

namespace QCAR {
    class ImageTracker;
    class MarkerTracker;
}

@interface AELVuforiaFacade : NSObject
{

    @public
    CGSize viewSize;
    CGRect viewport;
    
    @protected
    QCAR::INIT_FLAGS     qcarInitFlags;
    QCAR::IOS_INIT_FLAGS qcarRenderFlags;
    
    @private
    dispatch_queue_t    vuforia_queue;
    NSOperationQueue    *network_queue;
    QCAR::ImageTracker  *imageTracker;
    QCAR::MarkerTracker *markerTracker;
}

@property (nonatomic) CGSize viewSize;
@property (strong, nonatomic) NSURL *cacheDirectory;
@property (nonatomic) VuforiaVideoMode videoMode;
@property (nonatomic) VuforiaCameraFocusMode focusMode;
@property (nonatomic) BOOL cameraTorchMode;
@property (weak, nonatomic) id<AELVuforiaDelegate> delegate;

@end
