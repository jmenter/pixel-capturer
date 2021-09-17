
#import "AVCaptureDeviceFormat+Extras.h"

@implementation AVCaptureDeviceFormat (Extras)

- (NSString *)mediaSubType;
{
    FourCharCode code = CMFormatDescriptionGetMediaSubType(self.formatDescription);
    char letters[5];
    letters[0] = code >> 24;
    letters[1] = code >> 16;
    letters[2] = code >> 8;
    letters[3] = code >> 0;
    letters[4] = '\0';
    return [NSString stringWithCString:letters encoding:NSASCIIStringEncoding];
    
}

- (CGSize)videoDimensions;
{
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(self.formatDescription);
    return CGSizeMake(dimensions.width, dimensions.height);
}
@end
