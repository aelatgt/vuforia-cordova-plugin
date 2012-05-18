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

#import "NSURL+FileSystem.h"


@implementation NSURL (FileSystem)

-(NSString *)fileSystemEscapedString
{
	CFStringRef escaped = CFURLCreateStringByAddingPercentEscapes(    NULL,
														(__bridge CFStringRef)[self absoluteString],
														NULL,
														(CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
														kCFStringEncodingUTF8 
														);	
	NSString *escapedString = [NSString stringWithString: (__bridge NSString *)escaped];
	CFRelease(escaped);
	return escapedString;
}
@end
