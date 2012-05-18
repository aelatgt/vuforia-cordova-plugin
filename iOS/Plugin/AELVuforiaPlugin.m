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

#import "AELVuforiaPlugin.h"

@implementation AELVuforiaPlugin

@synthesize loadCallbacks   = _loadCallbacks;

- (CDVPlugin*) initWithWebView:(UIWebView*)theWebView
{
    self = (AELVuforiaPlugin *)[super initWithWebView:(UIWebView*)theWebView];
    if (self) 
	{

    }   
    return self;
}

- (void)returnDataSetInfo:(NSString *)callbackId keepCallback:(BOOL)bRetain
{
    CDVPluginResult *result = nil;
    NSMutableDictionary *returnInfo;
    NSString *jsString      = nil;

    NSURL *dataSetURL;
    
    returnInfo = [[NSMutableDictionary alloc] initWithCapacity: 4];
    
    [returnInfo setObject: [dataSetURL absoluteString] 
                   forKey: @"url"];
    
    result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK 
                           messageAsDictionary: returnInfo];
     
    [result setKeepCallbackAsBool:bRetain];
    
    jsString = [result toSuccessCallbackString:callbackId];    

    if (jsString) {
        [super writeJavascript:jsString];
    }
}

@end
