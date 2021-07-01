
#import "ViewController.h"

@import AVFoundation;

@interface ViewController()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (weak) IBOutlet NSView *myView;
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
    
    self.session = AVCaptureSession.new;
    AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeExternalUnknown] mediaType:nil position:AVCaptureDevicePositionUnspecified];
    self.devices = discoverySession.devices;
    self.myView.layer.backgroundColor = NSColor.blackColor.CGColor;
    [self.devicePopup removeAllItems];
    [self.devicePopup addItemsWithTitles:[self.devices valueForKey:@"localizedName"]];
    
    [self.formatPopup removeAllItems];
    
    [self.scalePopup removeAllItems];
    [self.scalePopup addItemsWithTitles:@[@"1x", @"2x", @"3x", @"4x"]];
    self.captureSessionQueue = dispatch_queue_create("captureSessionQueue", NULL);
    self.sampleBufferDelegateQueue = dispatch_queue_create("sampleBufferDelegateQueue", NULL);
    
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
    //        self.session.sessionPreset = AVCaptureSessionPreset960x540;
    [self.currentDeviceOutput setSampleBufferDelegate:self queue:self.sampleBufferDelegateQueue];
    //        NSArray<NSNumber *> * pixelFormatTypes =
    //        output.videoSettings = nil;
    //        output.availableVideoCVPixelFormatTypes
    //        AVCaptureVideoPreviewLayer *preview = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    //        preview.frame = self.myView.bounds;
    
    //        self.myView.wantsLayer = YES;
    //        self.myView.layer = preview;
    //        self.myView.layer.minificationFilter = kCAFilterNearest;
    //        self.myView.layer.magnificationFilter = kCAFilterNearest;
    
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

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate


- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection;
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    CIImage *image = [CIImage imageWithCVImageBuffer:imageBuffer];
    CGImageRef renderedImage = [CIContext.context createCGImage:image fromRect:image.extent];
    CGSize frameSize = image.extent.size;
    dispatch_async(dispatch_get_main_queue(), ^{
        
        CGFloat scalingFactor = 0.5;
        if (self.scalePopup.indexOfSelectedItem == 1) {
            scalingFactor = 1;
        }
        if (self.scalePopup.indexOfSelectedItem == 2) {
            scalingFactor = 1.5;
        }
        if (self.scalePopup.indexOfSelectedItem == 3) {
            scalingFactor = 2;
        }

        CGRect frame = self.myView.frame;
        frame.size.width = frameSize.width * scalingFactor;
        frame.size.height = frameSize.height * scalingFactor;
        frame.origin.x = 20;
        frame.origin.y = self.view.frame.size.height - frame.size.height - 78;
        self.myView.frame = frame;
        self.myView.layer.minificationFilter = kCAFilterNearest;
        self.myView.layer.magnificationFilter = kCAFilterNearest;
        self.myView.layer.contents = (__bridge id)renderedImage;
        self.frameSizeLabel.stringValue = [NSString stringWithFormat:@"video frame size (px): %@, view size (pt): %@, fps: %lld", NSStringFromSize(frameSize), NSStringFromSize(frame.size), self.currentlySelectedDevice.activeVideoMinFrameDuration.timescale / self.currentlySelectedDevice.activeVideoMinFrameDuration.value];
        CGImageRelease(renderedImage);
    });
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
}

@end
