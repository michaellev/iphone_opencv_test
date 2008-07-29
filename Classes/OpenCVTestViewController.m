#import "OpenCVTestViewController.h"

#include <opencv/cv.h>

@implementation OpenCVTestViewController
@synthesize imageView;

- (void)dealloc {
	[imageView dealloc];
	[super dealloc];
}

#pragma mark -
#pragma mark OpenCV Support Methods

// NOTE you SHOULD cvReleaseImage() for the return value when end of the code.
- (IplImage *)CreateIplImageFromUIImage:(UIImage *)image {
	CGImageRef imageRef = image.CGImage;

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	IplImage *iplimage = cvCreateImage(cvSize(image.size.width, image.size.height), IPL_DEPTH_8U, 4);
	CGContextRef contextRef = CGBitmapContextCreate(iplimage->imageData, iplimage->width, iplimage->height,
													iplimage->depth, iplimage->widthStep,
													colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
	CGContextDrawImage(contextRef, CGRectMake(0, 0, image.size.width, image.size.height), imageRef);
	CGContextRelease(contextRef);
	CGColorSpaceRelease(colorSpace);

	IplImage *ret = cvCreateImage(cvGetSize(iplimage), IPL_DEPTH_8U, 3);
	cvCvtColor(iplimage, ret, CV_RGBA2BGR);
	cvReleaseImage(&iplimage);

	return ret;
}

// NOTE You should convert color mode as RGB before passing to this function
- (UIImage *)UIImageFromIplImage:(IplImage *)image {
	NSLog(@"IplImage (%d, %d) %d bits by %d channels, %d bytes/row %s", image->width, image->height, image->depth, image->nChannels, image->widthStep, image->channelSeq);

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	NSData *data = [NSData dataWithBytes:image->imageData length:image->imageSize];
	CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
	CGImageRef imageRef = CGImageCreate(image->width, image->height,
										image->depth, image->depth * image->nChannels, image->widthStep,
										colorSpace, kCGImageAlphaNone|kCGBitmapByteOrderDefault,
										provider, NULL, false, kCGRenderingIntentDefault);
	UIImage *ret = [UIImage imageWithCGImage:imageRef];
	CGImageRelease(imageRef);
	CGDataProviderRelease(provider);
	CGColorSpaceRelease(colorSpace);
	return ret;
}

#pragma mark -
#pragma mark IBAction

- (IBAction)loadImage:(id)sender {
	if(!actionSheetAction) {
		UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@""
																 delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil
														otherButtonTitles:@"Use Photo from Library", @"Take Photo with Camera", @"Use Default Lena", nil];
		actionSheet.actionSheetStyle = UIActionSheetStyleDefault;
		actionSheetAction = ActionSheetToSelectTypeOfSource;
		[actionSheet showInView:self.view];
		[actionSheet release];
	}
}

- (IBAction)saveImage:(id)sender {
	if(imageView.image) {
		UIImageWriteToSavedPhotosAlbum(imageView.image, self, @selector(finishUIImageWriteToSavedPhotosAlbum:didFinishSavingWithError:contextInfo:), nil);
	}
}

- (void)finishUIImageWriteToSavedPhotosAlbum:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" message:@"The image was saved in the photo album"
												   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
	[alert show];	
	[alert release];
}

- (IBAction)edgeDetect:(id)sender {
	cvSetErrMode(CV_ErrModeParent);
	if(imageView.image) {
		// Create grayscale IplImage from UIImage
		IplImage *img_color = [self CreateIplImageFromUIImage:imageView.image];
		IplImage *img = cvCreateImage(cvGetSize(img_color), IPL_DEPTH_8U, 1);
		cvCvtColor(img_color, img, CV_BGR2GRAY);
		cvReleaseImage(&img_color);
		
		// Detect edge
		IplImage *img2 = cvCreateImage(cvGetSize(img), IPL_DEPTH_8U, 1);
		cvCanny(img, img2, 64, 128, 3);
		cvReleaseImage(&img);
		
		// Convert black and whilte to 24bit image then convert to UIImage to show
		IplImage *image = cvCreateImage(cvGetSize(img2), IPL_DEPTH_8U, 3);
		for(int i=0; i<img2->imageSize; i++) {
			image->imageData[i*3] = image->imageData[i*3+1] = image->imageData[i*3+2] = img2->imageData[i];
		}
		cvReleaseImage(&img2);
		imageView.image = [self UIImageFromIplImage:image];
		cvReleaseImage(&image);
	}
}

- (IBAction)faceDetect:(id)sender {
	cvSetErrMode(CV_ErrModeParent);
	if(imageView.image && !actionSheetAction) {
		UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@""
																 delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil
														otherButtonTitles:@"Bounding Box", @"Laughing Man", nil];
		actionSheet.actionSheetStyle = UIActionSheetStyleDefault;
		actionSheetAction = ActionSheetToSelectTypeOfMarks;
		[actionSheet showInView:self.view];
		[actionSheet release];
	}
}

#pragma mark -
#pragma mark UIViewControllerDelegate

- (void)loadView {
	[super loadView];
	imageView.image = nil;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	[self loadImage:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

#pragma mark -
#pragma mark UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	switch(actionSheetAction) {
		case ActionSheetToSelectTypeOfSource: {
			UIImagePickerControllerSourceType sourceType;
			if (buttonIndex == 0) {
				sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
			} else if(buttonIndex == 1) {
				sourceType = UIImagePickerControllerSourceTypeCamera;
			} else if(buttonIndex == 2) {
				NSString *path = [[NSBundle mainBundle] pathForResource:@"lena" ofType:@"jpg"];
				imageView.image = [UIImage imageWithContentsOfFile:path];
				break;
			} else {
				// Cancel
				break;
			}
			if([UIImagePickerController isSourceTypeAvailable:sourceType]) {
				UIImagePickerController *picker = [[UIImagePickerController alloc] init];
				picker.sourceType = sourceType;
				picker.delegate = self;
				picker.allowsImageEditing = NO;
				[self presentModalViewController:picker animated:YES];
				[picker release];
			}
			break;
		}
		case ActionSheetToSelectTypeOfMarks: {
			if(buttonIndex != 0 && buttonIndex != 1) {
				break;
			}

			NSString *path;
			IplImage *image = [self CreateIplImageFromUIImage:imageView.image];

			// Scaling down
			IplImage *small_image = cvCreateImage(cvSize(image->width/2,image->height/2), IPL_DEPTH_8U, 3);
			cvPyrDown(image, small_image, CV_GAUSSIAN_5x5);
			int scale = 2;
			
			// Load XML
			path = [[NSBundle mainBundle] pathForResource:@"haarcascade_frontalface_default" ofType:@"xml"];
			CvHaarClassifierCascade* cascade = (CvHaarClassifierCascade*)cvLoad([path cStringUsingEncoding:NSASCIIStringEncoding], NULL, NULL, NULL);
			CvMemStorage* storage = cvCreateMemStorage(0);
			
			// Detect faces and draw rectangle on them
			CvSeq* faces = cvHaarDetectObjects(small_image, cascade, storage, 1.2f, 2, CV_HAAR_DO_CANNY_PRUNING, cvSize(20, 20));
			cvReleaseImage(&small_image);

			// Create canvas to show the results
			CGImageRef imageRef = imageView.image.CGImage;
			CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
			CGContextRef contextRef = CGBitmapContextCreate(NULL, imageView.image.size.width, imageView.image.size.height,
															CGImageGetBitsPerComponent(imageRef), CGImageGetBytesPerRow(imageRef),
															colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
			CGContextDrawImage(contextRef, CGRectMake(0, 0, imageView.image.size.width, imageView.image.size.height), imageRef);
			
			path = [[NSBundle mainBundle] pathForResource:@"laughing_man" ofType:@"png"];
			CGImageRef laughing_man = [UIImage imageWithContentsOfFile:path].CGImage;

			// Draw results on the iamge
			for(int i = 0; i < faces->total; i++) {
				NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

				// Calc the rect of faces
				CvRect cvrect = *(CvRect*)cvGetSeqElem(faces, i);
				CGRect face_rect = CGContextConvertRectToDeviceSpace(contextRef, CGRectMake(cvrect.x * scale, cvrect.y * scale, cvrect.width * scale, cvrect.height * scale));

				if(buttonIndex == 0) {
					CGContextStrokeRect(contextRef, face_rect);
				} else if(buttonIndex == 1) {
					CGContextDrawImage(contextRef, face_rect, laughing_man);
				}

				[pool release];
			}

			imageView.image = [UIImage imageWithCGImage:CGBitmapContextCreateImage(contextRef)];
			CGContextRelease(contextRef);
			CGColorSpaceRelease(colorSpace);

			cvReleaseMemStorage(&storage);
			cvReleaseHaarClassifierCascade(&cascade);

			break;
		}
	}
	actionSheetAction = 0;
}

#pragma mark -
#pragma mark UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker
		didFinishPickingImage:(UIImage *)image
				  editingInfo:(NSDictionary *)editingInfo
{
	imageView.image = image;
	[[picker parentViewController] dismissModalViewControllerAnimated:YES];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[[picker parentViewController] dismissModalViewControllerAnimated:YES];
}
@end