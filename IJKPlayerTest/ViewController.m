//
//  ViewController.m
//  IJKPlayerTest
//
//  Created by Myron on 2020/10/4.
//

#import "ViewController.h"
#import "IJKPlayerViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface ViewController ()<UIImagePickerControllerDelegate,UINavigationControllerDelegate>


@end

@implementation ViewController


- (void)viewDidLoad{
    [super viewDidLoad];
    
    UIButton *buttonLocal = [[UIButton alloc] initWithFrame:CGRectMake(0, 200, 100, 50)];
    CGPoint center =  buttonLocal.center;
    center.x = self.view.bounds.size.width / 2;
    buttonLocal.center = center;
    [buttonLocal setTitle:@"本地" forState:(UIControlStateNormal)];
    buttonLocal.backgroundColor = [UIColor blackColor];
    [buttonLocal addTarget:self action:@selector(localVideo) forControlEvents:(UIControlEventTouchUpInside)];
    [self.view addSubview:buttonLocal];
    
    UIButton *buttonUrl = [[UIButton alloc] initWithFrame:CGRectMake(0, 300, 100, 50)];
    center =  buttonUrl.center;
    center.x = self.view.bounds.size.width / 2;
    buttonUrl.center = center;
    [buttonUrl setTitle:@"网络" forState:(UIControlStateNormal)];
    buttonUrl.backgroundColor = [UIColor blackColor];
    [buttonUrl addTarget:self action:@selector(urlVideo) forControlEvents:(UIControlEventTouchUpInside)];
    [self.view addSubview:buttonUrl];

}

-(void)localVideo{
    [self startMediaBrowserFromViewController:self usingDelegate:self];
}

-(void)urlVideo{
    //http://las-tech.org.cn/kwai/las-test_sd1000d.flv
    //http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8
    //http://videoplay.elearnmooc.com/moocMain/video/e08956a5-df94-4856-96ad-e35bdbc884c4.mp4
    //http://mov.bn.netease.com/open-movie/nos/mp4/2015/03/25/SAKKKQR8I_sd.mp4
    
    NSURL *url = [NSURL URLWithString:@"http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8"];
    IJKPlayerViewController *ijkPlayerVC = [[IJKPlayerViewController alloc] initWithURL:url];
    [self presentViewController:ijkPlayerVC animated:YES completion:nil];
}

#pragma mark 本地视频

- (BOOL) startMediaBrowserFromViewController: (UIViewController*) controller
                               usingDelegate: (id <UIImagePickerControllerDelegate,
                                               UINavigationControllerDelegate>) delegate {

    if (([UIImagePickerController isSourceTypeAvailable:
          UIImagePickerControllerSourceTypeSavedPhotosAlbum] == NO)
        || (delegate == nil)
        || (controller == nil))
        return NO;

    UIImagePickerController *mediaUI = [[UIImagePickerController alloc] init];
    mediaUI.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;

    // Displays saved pictures and movies, if both are available, from the
    // Camera Roll album.
    mediaUI.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeMovie, nil];

    // Hides the controls for moving & scaling pictures, or for
    // trimming movies. To instead show the controls, use YES.
    mediaUI.allowsEditing = NO;

    mediaUI.delegate = delegate;

    [controller presentViewController:mediaUI animated:YES completion:nil];
    return YES;
}

#pragma mark UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    NSURL *movieUrl;

    // Handle a movied picked from a photo album
    if (CFStringCompare ((CFStringRef) mediaType, kUTTypeMovie, 0)
        == kCFCompareEqualTo) {

        NSString *moviePath = [[info objectForKey:
                                UIImagePickerControllerMediaURL] path];
        movieUrl = [NSURL URLWithString:moviePath];
    }

    [self dismissViewControllerAnimated:YES completion:^(void){
        [self.navigationController pushViewController:[[IJKPlayerViewController alloc]   initWithURL:movieUrl] animated:YES];
    }];
}

@end
