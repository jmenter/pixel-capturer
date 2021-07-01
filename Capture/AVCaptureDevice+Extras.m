
#import "AVCaptureDevice+Extras.h"

@implementation AVCaptureDevice (Extras)

- (CGFloat)framesPerSecond;
{
    return self.activeVideoMinFrameDuration.timescale / self.activeVideoMinFrameDuration.value;
}

@end
