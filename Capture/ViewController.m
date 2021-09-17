
#import "ViewController.h"
#import "AVCaptureDevice+Extras.h"
#import "AVCaptureDeviceFormat+Extras.h"

@import AVFoundation;

@interface ViewController()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (weak) IBOutlet NSView *pixelView;
@property (weak) IBOutlet NSTextField *frameSizeLabel;

@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *currentDeviceInput;
@property (nonatomic) AVCaptureVideoDataOutput *currentDeviceOutput;

@property (weak) IBOutlet NSPopUpButton *devicePopup;
@property (weak) IBOutlet NSPopUpButton *dimensionsPopup;
@property (weak) IBOutlet NSPopUpButton *formatPopup;
@property (weak) IBOutlet NSPopUpButton *frameRatePopup;
@property (weak) IBOutlet NSPopUpButton *scalingPopup;
@property (weak) IBOutlet NSPopUpButton *filterPopup;

@property NSUInteger displayPopupValue;

@property (nonatomic) dispatch_queue_t captureSessionQueue;
@property (nonatomic) dispatch_queue_t sampleBufferDelegateQueue;

@property (nonatomic) NSArray <AVCaptureDevice *> *devices;

@end

@implementation ViewController

- (void)viewDidLoad;
{
    [super viewDidLoad];

    [self.scalingPopup removeAllItems];
    [self.scalingPopup addItemsWithTitles:@[@"Fill", @"Aspect Fill", @"Integer", @"1x", @"2x", @"3x", @"4x"]];

    [self.filterPopup removeAllItems];
    [self.filterPopup addItemsWithTitles:@[ @"Nearest Neighbor", @"Bilinear", @"Trilinear"]];

    self.session = AVCaptureSession.new;
    self.devices = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeExternalUnknown] mediaType:nil position:AVCaptureDevicePositionUnspecified].devices;

    [self.devicePopup removeAllItems];
    [self.devicePopup addItemsWithTitles:[self.devices valueForKey:@"localizedName"]];

    [self.formatPopup removeAllItems];
    [self.dimensionsPopup removeAllItems];
    [self.frameRatePopup removeAllItems];
    self.captureSessionQueue = dispatch_queue_create("captureSessionQueue", NULL);
    self.sampleBufferDelegateQueue = dispatch_queue_create("sampleBufferDelegateQueue", NULL);
    
}

- (void)viewDidAppear;
{
    [super viewDidAppear];
    if (self.devices.count > 0) {
        [self devicePopupDidSelect:self.devicePopup];
    }
}

- (AVCaptureDevice *)currentlySelectedDevice;
{
    return self.devices[self.devicePopup.indexOfSelectedItem];
}

- (AVCaptureDeviceFormat *)currentlySelectedCaptureFormat;
{
    return self.currentlySelectedDevice.formats[self.formatPopup.indexOfSelectedItem];
}

- (void)configureCurrentlySelectedDevice;
{
    AVCaptureDevice *device = self.currentlySelectedDevice;
    if (!device) { return; }
    AVCaptureDeviceFormat *format = self.currentlySelectedCaptureFormat;
    if (!format) { return; }
    
    [self.session stopRunning];
    [device lockForConfiguration:nil];
    [self.session removeInput:self.currentDeviceInput];
    [self.session removeOutput:self.currentDeviceOutput];
    
    device.activeFormat = self.currentlySelectedCaptureFormat;
    self.currentDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    [self.session addInput:self.currentDeviceInput];
    self.currentDeviceOutput = AVCaptureVideoDataOutput.new;
    [self.session addOutput:self.currentDeviceOutput];

    self.pixelView.layer = nil;
    if (self.displayPopupValue == 0) {
        [self.currentDeviceOutput setSampleBufferDelegate:self queue:self.sampleBufferDelegateQueue];
    } else {
        CMFormatDescriptionRef description = device.activeFormat.formatDescription;
        CMVideoDimensions dim = CMVideoFormatDescriptionGetDimensions(description);
        NSLog(@"subtype: %@", device.activeFormat.mediaSubType);
        AVCaptureVideoPreviewLayer *preview = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
        CGSize frameSize = CGSizeMake(dim.width, dim.height);
        CGRect frame = self.pixelView.frame;
        frame.size.width = frameSize.width * self.currentlySelectedScalingFactor;
        frame.size.height = frameSize.height * self.currentlySelectedScalingFactor;
        frame.origin.x = 20;
        frame.origin.y = self.view.frame.size.height - frame.size.height - 78;
        self.pixelView.frame = frame;
        preview.frame = self.pixelView.bounds;
        self.pixelView.layer = preview;
        self.pixelView.layer.contentsGravity = kCAGravityResize;
        self.pixelView.layer.minificationFilter = kCAFilterNearest;
        self.pixelView.layer.magnificationFilter = kCAFilterNearest;
        self.pixelView.layer.sublayers.firstObject.magnificationFilter = kCAFilterNearest;
    }

    dispatch_async(self.captureSessionQueue, ^{
        [self.session startRunning];
        [device unlockForConfiguration];
    });
    
}
- (IBAction)devicePopupDidSelect:(NSPopUpButton *)sender;
{
    [self.formatPopup removeAllItems];
    [self.formatPopup addItemsWithTitles:[self.currentlySelectedDevice.formats valueForKey:@"description"]];

    [self configureCurrentlySelectedDevice];
}

- (IBAction)scalePopupDidSelect:(NSPopUpButton *)sender;
{
    [self configureCurrentlySelectedDevice];
}

- (IBAction)formatPopupDidSelect:(id)sender;
{
    [self configureCurrentlySelectedDevice];
}

- (IBAction)displayPopupDidSelect:(NSPopUpButton *)sender;
{
    self.displayPopupValue = sender.indexOfSelectedItem;
    [self configureCurrentlySelectedDevice];
}

- (CGFloat)currentlySelectedScalingFactor;
{
    CGFloat scalingFactor = self.scalingPopup.indexOfSelectedItem + 1;
    return scalingFactor / self.view.window.backingScaleFactor;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection;
{
    if (self.displayPopupValue == 1) {
        return;
    }
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    CIImage *imageFromBuffer = [CIImage imageWithCVImageBuffer:imageBuffer];
    CGImageRef imageRef = [CIContext.context createCGImage:imageFromBuffer fromRect:imageFromBuffer.extent];
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

    CGSize frameSize = imageFromBuffer.extent.size;
    dispatch_async(dispatch_get_main_queue(), ^{
        
        CGRect frame = self.pixelView.frame;
        frame.size.width = frameSize.width * self.currentlySelectedScalingFactor;
        frame.size.height = frameSize.height * self.currentlySelectedScalingFactor;
        frame.origin.x = 20;
        frame.origin.y = self.view.frame.size.height - frame.size.height - 78;
        self.pixelView.frame = frame;
        self.pixelView.layer.minificationFilter = kCAFilterNearest;
        self.pixelView.layer.magnificationFilter = kCAFilterNearest;
        self.pixelView.layer.contents = (__bridge id)imageRef;
        self.frameSizeLabel.stringValue = [NSString stringWithFormat:@"video frame size (px): %@, view size (pt): %@, fps: %0.2f, display density: %0.1f", NSStringFromSize(frameSize), NSStringFromSize(frame.size), self.currentlySelectedDevice.framesPerSecond, self.view.window.backingScaleFactor];
        CGImageRelease(imageRef);
    });
}

@end
