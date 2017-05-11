//
//  ViewController.m
//  iconTest
//
//  Created by wangyaning on 2017/5/3.
//  Copyright © 2017年 wangyaning. All rights reserved.
//

#import "ViewController.h"
#import "HTTPServer.h"
#import "DDLog.h"
#import "DDTTYLogger.h"


#define IsEmptyString(s)  (((s) == nil) || ([(s) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0))
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
@interface ViewController ()<UIImagePickerControllerDelegate,UINavigationControllerDelegate>

/**
 *  创建UIImagePickerController对象
 */
@property (nonatomic, strong) UIImagePickerController * pickerImage;

@property (nonatomic, weak) UIImageView *imageV;

@property (nonatomic, strong) NSMutableArray *rectArr;

@property (nonatomic,strong)HTTPServer *httpServer;

@property (nonatomic, copy) NSString *webRootDir;

@property (nonatomic, copy) NSString *mainPage;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _rectArr = [NSMutableArray array];
    UIImageView *backImg = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
    [self.view addSubview:backImg];
    _imageV = backImg;
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    
    for (int i = 0; i<24; i++) {
        
        CALayer *layer = [[CALayer alloc] init];
        layer.frame = CGRectMake(54/2+i%6*(60+54/2), 56/2+i/4*(60+56/2), 120/2, 120/2);
        layer.cornerRadius = 10;
        layer.borderWidth = 1;
        layer.borderColor = [UIColor redColor].CGColor;
       // [self.view.layer addSublayer:layer];
        
        CGRect btnRect = CGRectMake(54/2+i%4*(60+54/2), 56/2+i/4*(60+56/2), 120/2, 120/2);
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = btnRect;
        button.layer.cornerRadius = 10;
        button.layer.borderColor = [UIColor redColor].CGColor;
        button.layer.borderWidth = 1;
        button.tag = 100+i;
        [button addTarget:self action:@selector(btnClick:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];
        
        
        
    }
    
}

- (void)btnClick:(UIButton *)button{
    
    if (_imageV.image.size.height ==  0) {
        [self showAlertWithMessage:@"没图"];
        return;
    }
    
    if (!(_imageV.image.size.height == 1334)&&!(_imageV.image.size.width == 750)) {
        
         [self showAlertWithMessage:@"图片分辨率不对，请长按图标成编辑模式后滑到最后一屏，然后截图"];
        return;
    }
    
    CGRect rect = CGRectMake(button.frame.origin.x*2, button.frame.origin.y*2, button.frame.size.width*2, button.frame.size.height*2);
 
    UIImage *image = [self imageWithSourceImage:_imageV.image clipRect:rect];
    
    
    UIImageView *imageV = [[UIImageView alloc] initWithFrame:button.frame];
    imageV.image = image;
    [self.view addSubview:imageV];
    
    NSData *imageData = UIImagePNGRepresentation(image);
    NSString *encodedImageStr = [imageData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    
    
    NSString *url = [NSString stringWithFormat:@"<!DOCTYPE HTML><html><head><meta name=\"apple-mobile-web-app-capable\" content=\"yes\"><meta name=\"apple-mobile-web-app-status-bar-style\" content=\"black\"><meta content=\"text/html charset=UTF-8\" http-equiv=\"Content-Type\" /><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, user-scalable=no\" /><title></title><link rel=\"apple-touch-icon-precomposed\" href=\"data:image/png;base64,%@\" /></head><body bgcolor=\"#ffffff\"><a href=\"weixin://scanqrcode\" id=\"qbt\" style=\"display: none\"></a><span id=\"msg\"></span></body><script>if (window.navigator.standalone == true){var lnk = document.getElementById(\"qbt\");var evt = document.createEvent('MouseEvent');evt.initMouseEvent('click');lnk.dispatchEvent(evt)}else{document.getElementById(\"msg\").innerHTML='<p><img width = \"100%%\" src=\"http://appby.us/sunroof/1.png\" alt=""></p><p><img width = \"100%%\" src=\"http://appby.us/sunroof/2.png\"alt=\"\"></p><p><img width = \"100%%\" src=\"http://appby.us/sunroof/3.png\" alt=\"\"></p>'}</script></html>",encodedImageStr];
    
    NSData *data = [url dataUsingEncoding:NSUTF8StringEncoding];
    
    NSString *urlBase = [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    
    NSString *htmlStr = [NSString stringWithFormat:@"<!DOCTYPE html><html><head lang=\"en\"><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"><meta http-equiv=\"refresh\"content=\"0;data:text/html;charset=utf-8;base64,%@\"></head><body></body></html>",urlBase];
    
    NSData *htmlData = [htmlStr dataUsingEncoding:NSUTF8StringEncoding];
    
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = paths[0];
    self.webRootDir = [documentsPath stringByAppendingPathComponent:@"web"];
    BOOL isDirectory = YES;
    BOOL exsit = [[NSFileManager defaultManager] fileExistsAtPath:_webRootDir isDirectory:&isDirectory];
    if(!exsit){
        [[NSFileManager defaultManager] createDirectoryAtPath:_webRootDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    self.mainPage = [NSString stringWithFormat:@"%@/web/index.html",documentsPath];
    [htmlData writeToFile:_mainPage atomically:YES];
    
    
    
    
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    _httpServer = [[HTTPServer alloc] init];
    [_httpServer setType:@"_http._tcp."];
    
   // NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
    
    
    //DDLogInfo(@"Setting document root: %@", webPath);
    
    [_httpServer setDocumentRoot:self.webRootDir];
    
    [self startServer];
    
}

- (void)startServer
{
    // Start the server (and check for problems)
    
    NSError *error;
    if([_httpServer start:&error])
    {
        DDLogInfo(@"Started HTTP Server on port %hu", [_httpServer listeningPort]);
        
        // open the url.
        NSString *urlStrWithPort = [NSString stringWithFormat:@"http://localhost:%d",[_httpServer listeningPort]];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStrWithPort]];
    }
    else
    {
        DDLogError(@"Error starting HTTP Server: %@", error);
    }
}
- (UIImage *)imageWithSourceImage:(UIImage *)sourceImage
                         clipRect:(CGRect)clipRect
{
    CGImageRef imageRef = sourceImage.CGImage;
    CGImageRef subImageRef = CGImageCreateWithImageInRect(imageRef, clipRect);
    CGSize imageSize = clipRect.size;
    UIGraphicsBeginImageContext(imageSize);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextDrawImage(context, clipRect, subImageRef);
    UIImage *clipImage = [UIImage imageWithCGImage:subImageRef];
    UIGraphicsEndImageContext();
    return clipImage;
}
#pragma mark 创建UIImagePickerController对象
- (UIImagePickerController *)pickerImage
{
    if (_pickerImage == nil)
    {
        _pickerImage = [[UIImagePickerController alloc] init];
        _pickerImage.delegate = self;
        self.pickerImage.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    }
    return _pickerImage;
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    [picker.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor blackColor]}];
    [picker.navigationBar setTintColor:[UIColor blackColor]];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    
    
    [self presentViewController:picker animated:YES completion:nil];

    
    
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    
    [self dismissViewControllerAnimated:YES completion:^{
        UIImage *imageOriginal = [info objectForKey:UIImagePickerControllerOriginalImage];
        
            //UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
            //NSData*imgData = UIImageJPEGRepresentation(image, 0.5);
          　_imageV.image = imageOriginal;
        
    }];
    
}

- (void)showAlertWithMessage:(NSString*)message{
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *alertA = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    
    [alertController addAction:alertA];
    
    [self presentViewController:alertController animated:YES completion:nil];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
