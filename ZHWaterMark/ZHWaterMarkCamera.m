//
//  ZHWaterMarkCamera.m
//  水印相机
//
//  Created by xyj on 2017/10/25.
//  Copyright © 2017年 xyj. All rights reserved.
//

#import "ZHWaterMarkCamera.h"
#import "ZHWaterMarkTool.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>

#define kScreenBounds [UIScreen mainScreen].bounds
#define kScreenWidth  [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height
#define kSystemVersion [[[UIDevice currentDevice] systemVersion] floatValue]

@interface ZHWaterMarkCamera ()<UIGestureRecognizerDelegate,AVCapturePhotoCaptureDelegate,CLLocationManagerDelegate>

/*******AVFoundation部分*********/
/*
 捕获设备，通常是前置摄像头，后置摄像头，麦克风（音频输入）
 */
@property(nonatomic)AVCaptureDevice *device;
/**
 概念:是AVFoundation 捕捉类(capture classes)的中心
 */
@property (nonatomic, strong) AVCaptureSession *captureSession;
/** 输入设备
 */
@property (nonatomic, strong) AVCaptureDeviceInput *deviceInput;
//包含AVCaptureStillImageOutput/AVCapturePhotoOutput
@property (nonatomic,strong) AVCaptureOutput *captureOutput;
/** 针对AVCapturePhotoOutput 类似于 AVCaptureStillImageOutput 的 outputSettings */
@property (nonatomic, strong) AVCapturePhotoSettings *photoSettings;
/**  预览图层
 */
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
/*******界面控件*********/
//闪光灯按钮
@property (strong, nonatomic)  UIButton *flashButton;
/** 切换摄像头按钮 */
@property (nonatomic, strong) UIButton *switchButton;
/** 拍照按钮 */
@property (nonatomic, strong) UIButton *cameraButton;
/*******界面数据*********/
/**  记录开始的缩放比例 */
@property(nonatomic,assign)CGFloat beginGestureScale;
/** 最后的缩放比例 */
@property(nonatomic,assign)CGFloat effectiveScale;
/** 水印时间 */
@property (nonatomic, strong) NSString *timeString;
/** 水印日期 */
@property (nonatomic, strong) NSString *dateString;
/** 使用按钮 */
@property (nonatomic, strong) UIButton *useImageBtn;
/** 取消/重拍按钮 */
@property (nonatomic, strong) UIButton *leftButon;
/** 获取拍摄的照片 */
@property (nonatomic, strong) UIImage *image;
/** 闪光灯文字 */
@property (nonatomic, strong) UILabel *flashLabel;
/** 点击时的对焦框 */
@property (nonatomic)UIView *focusView;
/** 拍完照显示生成的照片，保证预览的效果和实际效果一致 */
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *topBlackView;
/*******获取地理位置*********/
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic,strong) CLGeocoder *geocoder;
//姓名//地址名称
@property (nonatomic,strong) NSString *userName;
@property (nonatomic,strong) NSString *adressStr;
@property (nonatomic,weak) UILabel *adressLabel;
@property (nonatomic,weak) UIImageView *bottomMaskView;
@property (nonatomic,copy) void (^complete)(UIImage *);
@end

@implementation ZHWaterMarkCamera
#pragma mark - 懒加载
//初始化设备
-(AVCaptureDevice *)device{
    if (_device == nil) {
        //拿到后置摄像头
        _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        //将闪光灯设置为自动,只试用与iOS<10.0
        if (kSystemVersion<10.0) {
            NSError *errors;
            [_device lockForConfiguration:&errors];
            if (errors) {
                //锁定失败
                return nil;
            }
            [_device setFlashMode:AVCaptureFlashModeAuto];
            [_device unlockForConfiguration];
        }
    }
    return _device ;
}
//初始化deviceInput
-(AVCaptureDeviceInput *)deviceInput{
    if (_deviceInput == nil) {
        if (!self.device) {
            //获取设备失败(模拟器)
            return nil;
        }
        NSError *error;
        _deviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.device error:&error];
        if (error) {
            return nil;
        }
    }
    return _deviceInput ;
}
//初始化捕捉会话
-(AVCaptureSession *)captureSession{
    if (_captureSession == nil) {
        _captureSession = [[AVCaptureSession alloc] init];
    }
    return _captureSession ;
}
//初始化AVCaptureOutput
-(AVCaptureOutput *)captureOutput{
    if (_captureOutput == nil) {
        //10.0之前的创建方式
        if (kSystemVersion < 10.0) {
            AVCaptureStillImageOutput *output = [[AVCaptureStillImageOutput alloc] init];
            //对输出进行配置支持哪些格式
            NSDictionary * outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey, nil];
            [output setOutputSettings:outputSettings];
            _captureOutput = output;
        } else {
            //10.0之后的创建方式
            //创建输出
            AVCapturePhotoOutput *photoOutput= [[AVCapturePhotoOutput alloc] init];
            //配置输出
            AVCapturePhotoSettings *photoOutputSet  = [AVCapturePhotoSettings photoSettings];
            //初始化闪光灯设置
            photoOutputSet.flashMode = AVCaptureFlashModeAuto;
            _photoSettings = photoOutputSet;
            [photoOutput setPhotoSettingsForSceneMonitoring:photoOutputSet];
            _captureOutput = photoOutput;
        }
    }
    return _captureOutput ;
}
//初始化预览图层
-(AVCaptureVideoPreviewLayer *)previewLayer{
    if (_previewLayer == nil) {
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
        _previewLayer.frame = CGRectMake(0, 0,kScreenWidth, kScreenHeight);
        self.view.layer.masksToBounds = YES;
        _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    return _previewLayer ;
}

#pragma mark - 系统方法
+(instancetype)makeWaterMarkCameraWithUserName:(NSString *)userName andCompletedBlock:(void (^)(UIImage *))complete{
    
    return [[self alloc] initWithName:userName andBlock: complete];
}
-(instancetype)initWithName:(NSString *)name andBlock:(void (^)(UIImage *))complete{
    if (self = [super init]) {
        _userName = name;
        _complete = complete;
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    //获取地理位置
    [self startLocation];
    //初始化设备装置
    [self initAVCaptureSession];
    //初始化UI界面
    [self configureUI];
    //初始化缩放比例
    self.effectiveScale = self.beginGestureScale = 1.0f;
}

- (void)viewDidDisappear:(BOOL)animated{
    
    [super viewDidDisappear:YES];
    if (self.captureSession) {
        //停止扫描
        //停止流
        [self.captureSession stopRunning];
    }
}
/**
 隐藏导航栏
 */
-(BOOL)prefersStatusBarHidden {
    return YES;
}
//只支持竖屏
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - 获取地理位置
- (void)startLocation {
    // 初始化定位管理器
    _locationManager = [[CLLocationManager alloc] init];
    [_locationManager requestAlwaysAuthorization];
    [_locationManager requestWhenInUseAuthorization];
    // 设置代理
    _locationManager.delegate = self;
    // 设置定位精确度到米
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    // 设置过滤器为无
    _locationManager.distanceFilter = kCLDistanceFilterNone;
    // 开始定位
    [_locationManager startUpdatingLocation];//开始定位之后会不断的执行代理方法更新位置会比较费电所以建议获取完位置即时关闭更新位置服务
    //初始化地理编码器
    _geocoder = [[CLGeocoder alloc] init];
}
#pragma mark - CLLocationManagerDelegate-
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations{
    CLLocation * location = locations.lastObject;
    [_geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        if (placemarks.count > 0) {
            CLPlacemark *placemark = [placemarks objectAtIndex:0];
            //获取城市
            NSString *city = placemark.locality;
            if (!city) {
                //四大直辖市的城市信息无法通过locality获得，只能通过获取省份的方法来获得（如果city为空，则可知为直辖市）
                city = placemark.administrativeArea;
            }
            // 位置名
            self.adressStr = placemark.name;
        }else {
            self.adressStr = @"获取位置失败";
        }
        //不用的时候关闭更新位置服务
        [self.locationManager stopUpdatingLocation];
        //更新地址label
        [self updateAdressLabel];
        //隐藏提示
        self.adressLabel.hidden = YES;
        //相机使能
        self.cameraButton.enabled = YES;
        //开始流
        if (self.captureSession) {
            //开始扫描
            //启动从输入到输出的数据流
            [self.captureSession startRunning];
        }
    }];
    
}
#pragma mark - 设备配置
- (void)initAVCaptureSession{
    //1.初始化捕获会话(懒加载)
    //2.初始化捕捉设备并配置设备(懒加载)
    //3.初始化输入捕获(懒加载)
    //4.初始化输出捕获(懒加载)
    //5.将输入输出分别添加到捕捉会话中
    //判断是否能够添输入到会话中
    if (![self.captureSession canAddInput:self.deviceInput]) {
        return;
    }
    if (![self.captureSession canAddOutput:self.captureOutput]) {
        return;
    }
    [self.captureSession addInput:self.deviceInput];
    [self.captureSession addOutput:self.captureOutput];
    //6.图层预览
    [self.view.layer addSublayer:self.previewLayer];
}

#pragma mark - 初始化UI
-(void)configureUI {
    //1.添加预览图层顶部的黑色导航栏
    self.topBlackView = [self createTopBlackView];
    //2.左上角日期时间显示view
    [self topMaskViewWithView:self.topBlackView];
    //3.添加底部黑色导航栏View
    UIView *bottomBlackView = [self bottomBlackView];
    //4.底部姓名/地址label
    self.bottomMaskView = [self bottomMaskViewWithView:bottomBlackView];
    //5.黄色对焦框添加(就是一个透明View然后添加边框即可)
    _focusView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 50, 50)];
    _focusView.layer.borderWidth = 1.0;
    _focusView.layer.borderColor =[UIColor orangeColor].CGColor;
    _focusView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_focusView];
    _focusView.hidden = YES;
    //6.给View添加点击手势(获取焦距)
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(focusGesture:)];
    [self.view addGestureRecognizer:tapGesture];
    //7.添加缩放手势
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    pinch.delegate = self;
    [self.view addGestureRecognizer:pinch];
    //获取位置前屏幕中间提示正在获取位置信息
    UILabel *adressLabel = [[UILabel alloc] init];
    adressLabel.text = @"位置获取中...";
    adressLabel.textColor = [UIColor whiteColor];
    adressLabel.textAlignment = NSTextAlignmentCenter;
    adressLabel.frame = CGRectMake((kScreenWidth-100)*0.5, kScreenHeight * 0.5, 100, 30);
    [self.view addSubview:adressLabel];
    self.view.backgroundColor = [UIColor blackColor];
    self.cameraButton.enabled = NO;
    self.adressLabel = adressLabel;
}
/**
 *  顶部黑色导航view
 */
-(UIView *)createTopBlackView {
    //创建一个顶部的View
    UIView *topBlackView = [ZHWaterMarkTool viewWithFrame:CGRectMake(0, 0, kScreenWidth, 50) WithSuperView:self.view];
    //在View上添加按钮
    /** 切换前置后置摄像头按钮 */
    _switchButton = [ZHWaterMarkTool buttonWithTitle:nil imageName:@"cameraBack" target:self action:@selector(switchCameraSegmentedControlClick:)];
    _switchButton.frame = CGRectMake(kScreenWidth-45, 12.5, 30, 23);
    [topBlackView addSubview:_switchButton];
    
    /** 闪光灯操作按钮 */
    //左边是按钮
    _flashButton = [ZHWaterMarkTool buttonWithTitle:nil imageName:@"camera_light_n" target:self action:@selector(flashButtonClick:)];
    _flashButton.frame = CGRectMake(20, 12.5, 13, 21);
    [topBlackView addSubview:_flashButton];
    //右边是"自动"标题
    _flashLabel = [ZHWaterMarkTool labelWithText:@"自动" fontSize:14 alignment:NSTextAlignmentCenter];
    _flashLabel.frame = CGRectMake(CGRectGetMaxX(_flashButton.frame), CGRectGetMinY(_flashButton.frame), 50, 21);
    [topBlackView addSubview:self.flashLabel];
    /** 因为闪光灯图标太小，点击比较费劲，所以添加一个空白按钮增大点击范围 */
    UIButton *tapButton = [ZHWaterMarkTool buttonWithTitle:nil imageName:nil target:self action:@selector(flashButtonClick:)];
    [tapButton setFrame:(CGRectMake(20, 0, 65, 50))];
    [tapButton setBackgroundColor:[UIColor clearColor]];
    [topBlackView addSubview:tapButton];
    
    return topBlackView;
}

/**
 *  顶部蒙版
 */
-(UIImageView *)topMaskViewWithView:(UIView *)view {
    //1.半透明imageView
    UIImageView *topMaskview = [[UIImageView alloc] initWithFrame:(CGRectMake(0, CGRectGetMaxY(view.frame), kScreenWidth, 100))];
    topMaskview.image = [UIImage imageNamed:@"markTopMView"];
    [self.view addSubview:topMaskview];
    //2.获得当前日期时间
    NSString *timeStr = timeStr = [ZHWaterMarkTool dateStingWithFormatterSting:@"yyyy.MM.dd hh:mm" andInputDate:nil];
    NSString *dateString = [timeStr substringWithRange:NSMakeRange(0, 10)];
    //时间字符串
    self.timeString = [timeStr substringWithRange:NSMakeRange(11, 5)];
    //获得今天星期几
    NSString *weekDay = [ZHWaterMarkTool weekdayStringFromDate:nil];
    //日期字符串
    self.dateString = [NSString stringWithFormat:@"%@ %@",dateString,weekDay];
    if (self.isTwelveHandle) {
        BOOL hasAMPM = [ZHWaterMarkTool isTwelveMechanism];
        int time = [ZHWaterMarkTool currentIntTime];
        self.timeString = hasAMPM ? [NSString stringWithFormat:@"%@%@",self.timeString,(time > 12 ? @"pm" : @"am")] : self.timeString;
    }
    //添加显示label
    //显示时间的label
    UILabel *label = [ZHWaterMarkTool labelWithText:self.timeString fontSize:30 alignment:0];
    label.frame = CGRectMake(20, 20, 150, 30);
    //显示日期的label
    UILabel *dateLabel = [ZHWaterMarkTool labelWithText:self.dateString fontSize:14 alignment:0];
    dateLabel.frame = CGRectMake(20, CGRectGetMaxY(label.frame)+5, 200, 15);
    [topMaskview addSubview:label];
    [topMaskview addSubview:dateLabel];
    return topMaskview;
}
/**
 *  底部黑色view
 */
-(UIView *)bottomBlackView {
    //底部导航栏View
    UIView *bottomBlackView = [ZHWaterMarkTool viewWithFrame:CGRectMake(0, kScreenHeight - 125, kScreenWidth, 125) WithSuperView:self.view];
    
    /** 拍照按钮 */
    self.cameraButton = [ZHWaterMarkTool buttonWithTitle:nil imageName:@"cameraPress" target:self action:@selector(takePhotoButtonClick:)];
    self.cameraButton.frame = CGRectMake(kScreenWidth*1/2.0-34, 23, 68, 68);
    [bottomBlackView addSubview:self.cameraButton];
    
    /** 取消/重拍 */
    self.leftButon = [ZHWaterMarkTool buttonWithTitle:@"取消" imageName:nil target:self action:@selector(cancle:)];
    self.leftButon.frame = CGRectMake(5, 32.5, 60, 60);
    [bottomBlackView addSubview:self.leftButon];
    
    /** 使用照片 */
    self.useImageBtn = [ZHWaterMarkTool buttonWithTitle:@"使用" imageName:nil target:self action:@selector(userImage:)];
    self.useImageBtn.frame = CGRectMake(kScreenWidth -65, 32.5, 50, 50);
    self.useImageBtn.hidden = YES;
    [bottomBlackView addSubview:self.useImageBtn];
    return bottomBlackView;
}
/**
 *  底部蒙版
 */
-(UIImageView *)bottomMaskViewWithView:(UIView *)bottomBlackView {
    //半透明ImgeView
    UIImageView *bottomMaskView = [ZHWaterMarkTool imageViewWithImageName:@"markBottomMView" superView:self.view frame:CGRectMake(0, CGRectGetMinY(bottomBlackView.frame) - 100, kScreenWidth, 100)];
    //添加姓名label
    CGFloat width = [ZHWaterMarkTool calculateRowWidth:self.userName fontSize:14 fontHeight:14];
    UILabel *userLabel = [ZHWaterMarkTool labelWithText:self.userName fontSize:14 alignment:2];
    userLabel.frame = CGRectMake(bottomMaskView.frame.size.width - width - 20, 35,width, 30);
    //小头像图标
    [ZHWaterMarkTool imageViewWithImageName:@"markUser" superView:bottomMaskView frame:CGRectMake(CGRectGetMinX(userLabel.frame)- 15, userLabel.center.y - 6.5, 13, 13)];
    [bottomMaskView addSubview:userLabel];
    //添加地址label
    CGFloat widthx = [ZHWaterMarkTool calculateRowWidth:@"地址信息" fontSize:14 fontHeight:14];
    UILabel *addLabel = [ZHWaterMarkTool labelWithText:@"地址信息" fontSize:14 alignment:2];
    addLabel.frame = CGRectMake(bottomMaskView.frame.size.width - widthx - 20, 60,widthx, 30);
    addLabel.tag = 101;
    //地址图标
    UIImageView *addimageView = [[UIImageView alloc] initWithFrame:CGRectMake(CGRectGetMinX(addLabel.frame)- 15, addLabel.center.y - 6.5, 13, 13)];
    addimageView.image = [UIImage imageNamed:@"icon_add"];
    addimageView.tag = 102;
    [bottomMaskView addSubview:addimageView];
    [bottomMaskView addSubview:addLabel];
    
    return bottomMaskView;
}
//获取到地址信息时更新地址label
-(void)updateAdressLabel{
    UIView *supppView = _bottomMaskView;
    UILabel *addLabel = [supppView viewWithTag:101];
    UIImageView *addImageView = [supppView viewWithTag:102];
    CGFloat widthx = [ZHWaterMarkTool calculateRowWidth:self.adressStr fontSize:14 fontHeight:14];
    addLabel.text = self.adressStr;
    addLabel.frame =  CGRectMake(_bottomMaskView.frame.size.width - widthx - 20, 60,widthx, 30);
    addImageView.frame = CGRectMake(CGRectGetMinX(addLabel.frame)- 15, addLabel.center.y - 6.5, 13, 13);
}

#pragma mark - 事件处理
//切换镜头
- (void)switchCameraSegmentedControlClick:(UIButton *)sender {
    //根据媒体类型拿到当前能输入媒体数据的所有可用的设备源(前/后置摄像头,这时没有用到语音,因此不可用的)
    NSUInteger cameraCount = [self obtainAvailableDevices].count;
    //说明前后摄像头都能用
    if (cameraCount > 1) {
        NSError *error;
        //添加旋转动画
        CATransition *animation = [CATransition animation];
        animation.duration = .3f;
        animation.type = @"oglFlip";
        //新的设备新的输入
        AVCaptureDevice *newCamera = nil;
        AVCaptureDeviceInput *newInput = nil;
        //拿到当前设备的位置
        AVCaptureDevicePosition position = self.deviceInput.device.position;
        if (position == AVCaptureDevicePositionFront){
            //如果当前为前置,那就拿到后置
            newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
            //动画左向右翻转
            animation.subtype = kCATransitionFromLeft;
            //前置到后置,显示闪光灯
            self.flashButton.hidden = NO;
            self.flashLabel.hidden = NO;
        }else {
            //当前为后置,那就拿到前置
            newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
            //动画从右往左翻转
            animation.subtype = kCATransitionFromRight;
            //后置到前置,隐藏闪光灯
            self.flashButton.hidden = YES;
            self.flashLabel.hidden = YES;
        }
        //添加动画到图层
        [self.previewLayer addAnimation:animation forKey:nil];
        //根据新的设备创建新的输入捕捉
        newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:nil];
        if (newInput != nil) {
            //捕捉会话开始配置
            [self.captureSession beginConfiguration];
            //移除捕捉输入
            [self.captureSession removeInput:self.deviceInput];
            //添加新的捕捉输入
            if ([self.captureSession canAddInput:newInput]) {
                [self.captureSession addInput:newInput];
                self.deviceInput = newInput;
            } else {
                [self.captureSession addInput:self.deviceInput];
            }
            //提交会话配置
            [self.captureSession commitConfiguration];
            
        } else if (error) {
            NSLog(@"toggle carema failed, error = %@", error);
        }
    }
}
//拿到所有可用的摄像头(video)设备
-(NSArray *)obtainAvailableDevices{
    if (kSystemVersion < 10.0) {
        return [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    } else {
        AVCaptureDeviceDiscoverySession *deviceSession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera,AVCaptureDeviceTypeBuiltInDualCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
        return deviceSession.devices;
    }
}
//根据前后位置拿到相应的设备
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
    NSArray *devices = [self obtainAvailableDevices];
    if (!devices) {
        return nil;
    }
    for ( AVCaptureDevice *device in devices ){
        if ( device.position == position ){
            return device;
        }
    }
    return nil;
}
//闪光灯模式切换
- (void)flashButtonClick:(UIButton *)sender {
    //拿到后置摄像头
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //自动->打开->关闭
    //必须判定是否有闪光灯，否则如果没有闪光灯会崩溃
    if (!device.hasFlash) {
          NSLog(@"设备不支持闪光灯");
        return ;
    }
    AVCaptureFlashMode tempflashMode = AVCaptureFlashModeOff;
    //拿到当前设备的闪光状态
    AVCaptureFlashMode xxflshMode = kSystemVersion >10.0 ? self.photoSettings.flashMode : device.flashMode;
    switch (xxflshMode) {
        case AVCaptureFlashModeOff: {//关闭->自动
            tempflashMode = AVCaptureFlashModeAuto;
            self.flashLabel.text = @"自动";
            break;
        }
        case AVCaptureFlashModeOn: {//开->关闭
            tempflashMode = AVCaptureFlashModeOff;
            self.flashLabel.text = @"关闭";
            break;
        }
        case AVCaptureFlashModeAuto: {//自动->打开
            tempflashMode = AVCaptureFlashModeOn;
            self.flashLabel.text = @"打开";
            break;
        }
        default:
            break;
    }
    if (kSystemVersion < 10.0) {
        //修改前必须先锁定
        [device lockForConfiguration:nil];
        if ([device isFlashModeSupported:tempflashMode])
            [device setFlashMode:tempflashMode];
        [device unlockForConfiguration];
    }else{
        //修改outputseting的闪光灯模式
        self.photoSettings.flashMode = tempflashMode;
    }
}
//点击拍照
- (void)takePhotoButtonClick:(UIButton *)sender {
    
    self.useImageBtn.hidden = NO;
    self.flashLabel.hidden = YES;
    self.flashButton.hidden = YES;
    self.switchButton.hidden = YES;
    [self.leftButon setTitle:@"重拍" forState:(UIControlStateNormal)];
    sender.hidden = YES;
    //拿到连接
    AVCaptureConnection *stillImageConnection = [self.captureOutput connectionWithMediaType:AVMediaTypeVideo];
    //拿到当前手机方向
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    //根据当前手机方向设置摄像头拍摄方向
    AVCaptureVideoOrientation avcaptureOrientation = [self avOrientationForDeviceOrientation:curDeviceOrientation];
    //设置图片方向
    [stillImageConnection setVideoOrientation:avcaptureOrientation];
    //设置缩放比例
    [stillImageConnection setVideoScaleAndCropFactor:self.effectiveScale];
    if (kSystemVersion <10.0) {
        AVCaptureStillImageOutput *stillImageOutput = (AVCaptureStillImageOutput *)self.captureOutput;
        //生成静态图像数据
        [stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            
            if (imageDataSampleBuffer == NULL) {
                return ;
            }
            //拿到图片数据流
            NSData *jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            //生成image图片(注意:这个image是没有时间/个人信息/地址信息的)
             [self dealWithImage:[UIImage imageWithData:jpegData]];
        }];
    }else{
        AVCapturePhotoSettings *newSettings = [AVCapturePhotoSettings photoSettingsFromPhotoSettings:self.photoSettings];
        AVCapturePhotoOutput *photoOutput =  (AVCapturePhotoOutput *)self.captureOutput;
        if (![photoOutput.supportedFlashModes containsObject:@(newSettings.flashMode)]) {
            newSettings.flashMode = AVCaptureFlashModeOff;
        }
        [photoOutput capturePhotoWithSettings:newSettings delegate:self];
    }
}
//处理图片
-(void)dealWithImage:(UIImage *)image{
    if (self.deviceInput.device.position == AVCaptureDevicePositionFront) {
      UIImageOrientation imgOrientation = UIImageOrientationLeftMirrored;
       image = [[UIImage alloc]initWithCGImage:image.CGImage scale:1.0f orientation:imgOrientation];
    }
    //重新画一张图片(将时间/个人信息/地址信息画上去)
    self.image = [self drawMarkImage:image];
    //停止流
    [self.captureSession stopRunning];
    //展示图片view
    //防止重复添加
    if (self.imageView) {
        [self.imageView removeFromSuperview];
    }
    self.imageView = [[UIImageView alloc]initWithFrame:self.previewLayer.frame];
    [self.view insertSubview:_imageView belowSubview:_topBlackView];
    self.imageView.layer.masksToBounds = YES;
    self.imageView.image = image;
}
//根据当前手机方向拿到摄像头拍摄方向
- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation{
    AVCaptureVideoOrientation result = (AVCaptureVideoOrientation)deviceOrientation;
    if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
        result = AVCaptureVideoOrientationLandscapeRight;
        else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
            result = AVCaptureVideoOrientationLandscapeLeft;
            return result;
}

//取消/重拍
-(void)cancle:(UIButton *)sender {
    if ([sender.titleLabel.text isEqualToString:@"取消"]) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [sender setTitle:@"取消" forState:(UIControlStateNormal)];
        [self.imageView removeFromSuperview];
        self.cameraButton.hidden = NO;
        self.useImageBtn.hidden = YES;
        self.switchButton.hidden = NO;
        //判断当前摄像头方向,如果前置隐藏闪光设置,反之显示
        AVCaptureDevicePosition position = self.deviceInput.device.position;
        if (position == AVCaptureDevicePositionFront) {
            self.flashLabel.hidden = YES;
            self.flashButton.hidden = YES;
        }else{
            self.flashLabel.hidden = NO;
            self.flashButton.hidden = NO;
        }
        //重新开始流
        [self.captureSession startRunning];
    }
}
//使用图片调用代理方法返回图片
-(void)userImage:(UIButton *)button {
    if (_complete) {
        _complete(self.image);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}
//点击聚焦
- (void)focusGesture:(UITapGestureRecognizer*)gesture{
    //拿到点击点
    CGPoint point = [gesture locationInView:gesture.view];
    //设置聚焦
    [self focusAtPoint:point];
}
- (void)focusAtPoint:(CGPoint)point{
    CGSize size = self.view.bounds.size;
    //点击除了上下黑色导航栏以内的才会聚焦
    if (point.y > (kScreenHeight - 125)||point.y < 50) {
        return;
    }
    //找到聚焦位置(注意该point是在屏幕的比例位置)
    CGPoint focusPoint = CGPointMake( point.y /size.height ,1-point.x/size.width );
    NSError *error;
    if ([self.device lockForConfiguration:&error]) {
        //对焦模式和对焦点
        if ([self.device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            [self.device setFocusPointOfInterest:focusPoint];
            [self.device setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        //曝光模式和曝光点
        if ([self.device isExposureModeSupported:AVCaptureExposureModeAutoExpose ]) {
            [self.device setExposurePointOfInterest:focusPoint];
            [self.device setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        [self.device unlockForConfiguration];
        //设置对焦动画
        _focusView.center = point;
        _focusView.hidden = NO;
        [UIView animateWithDuration:0.3 animations:^{
            //先放大1.25倍
            _focusView.transform = CGAffineTransformMakeScale(1.25, 1.25);
        }completion:^(BOOL finished) {
            [UIView animateWithDuration:0.5 animations:^{
                //再返回原来的尺寸
                _focusView.transform = CGAffineTransformIdentity;
            } completion:^(BOOL finished) {
                _focusView.hidden = YES;
            }];
        }];
    }
}
//缩放手势 用于调整焦距(设置图层的缩放比例)
- (void)handlePinchGesture:(UIPinchGestureRecognizer *)recognizer{
    
    BOOL allTouchesAreOnThePreviewLayer = YES;
    //拿到触摸点(几根手指)
    NSUInteger numTouches = [recognizer numberOfTouches];
    for (int i = 0; i < numTouches; ++i) {
        //拿到每个触摸点的位置
        CGPoint location = [recognizer locationOfTouch:i inView:self.view];
        CGPoint convertedLocation = [self.previewLayer convertPoint:location fromLayer:self.previewLayer.superlayer];
        if ( ! [self.previewLayer containsPoint:convertedLocation] ) {
            allTouchesAreOnThePreviewLayer = NO;
            break;
        }
    }
    if (allTouchesAreOnThePreviewLayer) {
        //设置缩放比例
        self.effectiveScale = self.beginGestureScale * recognizer.scale;
        if (self.effectiveScale < 1.0){
            self.effectiveScale = 1.0;
        }
        CGFloat maxScaleAndCropFactor = [[self.captureOutput connectionWithMediaType:AVMediaTypeVideo] videoMaxScaleAndCropFactor];
        if (self.effectiveScale > maxScaleAndCropFactor)
            self.effectiveScale = maxScaleAndCropFactor;
        //添加缩放动画到图层上
        [CATransaction begin];
        [CATransaction setAnimationDuration:.025];
        [self.previewLayer setAffineTransform:CGAffineTransformMakeScale(self.effectiveScale, self.effectiveScale)];
        [CATransaction commit];
    }
}

#pragma mark - gestureRecognizer delegate
//开始缩放时调用
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer{
    if ( [gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]] ) {
        //开始缩放屏幕前初始化缩放比例
        self.beginGestureScale = self.effectiveScale;
    }
    return YES;
}
#pragma mark - AVCapturePhotoCaptureDelegate
//用于监视照片的拍摄过程
-(void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishProcessingPhotoSampleBuffer:(CMSampleBufferRef)photoSampleBuffer previewPhotoSampleBuffer:(CMSampleBufferRef)previewPhotoSampleBuffer resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings error:(NSError *)error{
    if (error) {
        NSLog(@"error : %@", error.localizedDescription);
        return;
    }
    if (!photoSampleBuffer) {
        return;
    }
    NSData *data = [AVCapturePhotoOutput JPEGPhotoDataRepresentationForJPEGSampleBuffer:photoSampleBuffer previewPhotoSampleBuffer:previewPhotoSampleBuffer];
    [self dealWithImage:[UIImage imageWithData:data]];
}

#pragma mark - 画图层
/**
 *  绘制带水印的图片
 */
-(UIImage *)drawMarkImage:(UIImage *)image  {
    //开启位图上下文
    UIGraphicsBeginImageContextWithOptions([UIScreen mainScreen].bounds.size, NO, 0.0);
    //将相机拍到的图片画到上下文
    [image drawInRect:kScreenBounds];
    
    /** 顶部蒙版 */
    CGRect rectTopMask = CGRectMake(0, 0, kScreenWidth, 100);
    UIImage *imageTopMask = [UIImage imageNamed:@"markTopMView"];
    [imageTopMask drawInRect:rectTopMask];
    
    /** 时间 */
    CGRect rectTime = CGRectMake(20, 15, 200, 30);
    NSDictionary *dicTime = @{NSFontAttributeName:[UIFont systemFontOfSize:30],NSForegroundColorAttributeName:[UIColor whiteColor]};
    [self.timeString drawInRect:rectTime withAttributes:dicTime];
    
    /** 日期 */
    CGRect rectDate = CGRectMake(20, CGRectGetMaxY(rectTime) + 5, 200, 25);
    NSDictionary *dicDate = @{NSFontAttributeName:[UIFont systemFontOfSize:15],NSForegroundColorAttributeName:[UIColor whiteColor]};
    [self.dateString drawInRect:rectDate withAttributes:dicDate];
    
    /** 底部蒙版 */
    CGRect rectBottomMask = CGRectMake(0, kScreenHeight - 110, kScreenWidth, 110);
    UIImage *imageBottomMask = [UIImage imageNamed:@"markBottomMView"];
    [imageBottomMask drawInRect:rectBottomMask];
    
    /** logo */
    UIImage *logo = [UIImage imageNamed:@"markLogo"];
    [logo drawInRect:CGRectMake(kScreenWidth - 103, kScreenHeight - 70, 83,20)];
    
    /** 用户名 */
    CGFloat width1 = [ZHWaterMarkTool calculateRowWidth:self.userName fontSize:14 fontHeight:20];
    CGRect rectUserName = CGRectMake(kScreenWidth - width1 - 20, kScreenHeight - 90, width1, 20);
    NSDictionary *dicUserName = @{NSFontAttributeName:[UIFont systemFontOfSize:14],NSForegroundColorAttributeName:[UIColor whiteColor]};
    [self.userName drawInRect:rectUserName withAttributes:dicUserName];
    
    /** 用户图标 */
    UIImage *imageUser = [UIImage imageNamed:@"markUser"];
    CGRect rectUser = CGRectMake(CGRectGetMinX(rectUserName) - 20, CGRectGetMinY(rectUserName), 13, 13);
    [imageUser drawInRect:rectUser];
    //地址名/地址图标
    /** 地址名 */
    CGFloat width2 = [ZHWaterMarkTool calculateRowWidth:self.adressStr fontSize:14 fontHeight:20];
    CGRect rectadd = CGRectMake(kScreenWidth - width2 - 20, kScreenHeight - 70, width2, 20);
    NSDictionary *dicadd = @{NSFontAttributeName:[UIFont systemFontOfSize:14],NSForegroundColorAttributeName:[UIColor whiteColor]};
    [self.adressStr drawInRect:rectadd withAttributes:dicadd];
    
    /** 地址图标 */
    UIImage *imageadd = [UIImage imageNamed:@"icon_add"];
    CGRect rectadd2 = CGRectMake(CGRectGetMinX(rectadd) - 20, CGRectGetMinY(rectadd), 13, 13);
    [imageadd drawInRect:rectadd2];
    //生成新的图片
    UIImage *newPic = UIGraphicsGetImageFromCurrentImageContext();
    //关闭图层上下文
    UIGraphicsEndImageContext();

    return newPic;
}
@end
