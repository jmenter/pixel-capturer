
#import "ViewController.h"
#import "AVCaptureDevice+Extras.h"

@import AVFoundation;

@interface ViewController()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (weak) IBOutlet NSView *pixelView;
@property (weak) IBOutlet NSTextField *frameSizeLabel;

@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *currentDeviceInput;
@property (nonatomic) AVCaptureVideoDataOutput *currentDeviceOutput;

@property (weak) IBOutlet NSPopUpButton *devicePopup;
@property (weak) IBOutlet NSPopUpButton *formatPopup;
@property (weak) IBOutlet NSPopUpButton *scalePopup;

@property (nonatomic) dispatch_queue_t captureSessionQueue;
@property (nonatomic) dispatch_queue_t sampleBufferDelegateQueue;

@property (nonatomic) NSArray <AVCaptureDevice *> *devices;
@end

@implementation ViewController

- (void)viewDidLoad;
{
    [super viewDidLoad];

    [self.scalePopup removeAllItems];
    [self.scalePopup addItemsWithTitles:@[@"1x", @"2x", @"3x", @"4x"]];

    self.session = AVCaptureSession.new;
    AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeExternalUnknown] mediaType:nil position:AVCaptureDevicePositionUnspecified];
    self.devices = discoverySession.devices;

    [self.devicePopup removeAllItems];
    [self.devicePopup addItemsWithTitles:[self.devices valueForKey:@"localizedName"]];

    [self.formatPopup removeAllItems];

    self.captureSessionQueue = dispatch_queue_create("captureSessionQueue", NULL);
    self.sampleBufferDelegateQueue = dispatch_queue_create("sampleBufferDelegateQueue", NULL);
    
}

- (void)viewDidAppear;
{
    [super viewDidAppear];
    [self devicePopupDidSelect:self.devicePopup];
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
    [self.currentDeviceOutput setSampleBufferDelegate:self queue:self.sampleBufferDelegateQueue];

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

- (IBAction)formatPopupDidSelect:(id)sender;
{
    [self configureCurrentlySelectedDevice];
}

- (CGFloat)currentlySelectedScalingFactor;
{
    CGFloat scalingFactor = self.scalePopup.indexOfSelectedItem + 1;
    return scalingFactor / self.view.window.backingScaleFactor;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection;
{
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
