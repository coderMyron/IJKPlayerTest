//
//  IJKPlayerViewController.m
//  IJKPlayerTest
//
//  Created by Myron on 2020/10/6.
//

#import "IJKPlayerViewController.h"
#import <IJKMediaFramework/IJKMediaFramework.h>
#import "TouchButton.h"

#define kIsFullScreen ((([[[UIDevice currentDevice] systemVersion] floatValue] >= 11.0f) && ([[[[UIApplication sharedApplication] windows] objectAtIndex:0] safeAreaInsets].bottom > 0.0))? YES : NO) // 判断是否全面屏
#define kNavigationBarHeight (kIsFullScreen ? 88.f : 64.f)   // 导航栏高度

typedef NS_ENUM(NSUInteger, Direction) {
    DirectionLeftOrRight,
    DirectionUpOrDown,
    DirectionNone
};

@interface IJKPlayerViewController ()<TouchButtonDelegate>

@property(atomic, strong) NSURL *url;
@property(atomic, retain) id <IJKMediaPlayback> player;
@property(nonatomic,weak) UIView *playerView;
@property(nonatomic,weak) UIButton *buttonPlay;
@property(nonatomic,weak) UILabel *lableCurrentTime;
@property(nonatomic,weak) UILabel *lableTotalTime;
@property(nonatomic,weak) UISlider *sliderProgress;
@property(nonatomic,assign) Direction direction;
@property(nonatomic,strong) TouchButton *touchButton;//声音亮度滑动播放快进快退控件
@property(nonatomic,assign) CGPoint startPoint;//开始滑动前的点
@property(nonatomic,assign) CGFloat startVB;//开始前的亮度或者音量值
@property(nonatomic,assign) CGFloat startVideoRate;//开始滑动前的比率
@property(nonatomic,strong) MPVolumeView *volumeView;//控制音量的view
@property(nonatomic,strong) UISlider* volumeViewSlider;//控制音量
@property(nonatomic,assign) CGFloat currentRate;//当期视频播放的进度


@end

@implementation IJKPlayerViewController
{
    BOOL _isMediaSliderBeingDragged;
    BOOL _isStop;
//    BOOL _isPlay;
}

- (instancetype)initWithURL:(NSURL *)url {
    self = [self init];
    if (self) {
        self.url = url;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.whiteColor;
    
    UIView *displayView = [[UIView alloc] initWithFrame:CGRectMake(0, kNavigationBarHeight, self.view.bounds.size.width, self.view.bounds.size.width * 9 / 16)];
    self.playerView = displayView;
    self.playerView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.playerView];
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
    button.center = CGPointMake(self.view.bounds.size.width / 2, 200 / 2 + self.view.bounds.size.width * 9 / 16);
    [button setTitle:@"播放" forState:(UIControlStateNormal)];
    button.backgroundColor = [UIColor blackColor];
    [button addTarget:self action:@selector(playVideo) forControlEvents:(UIControlEventTouchUpInside)];
    [self.view addSubview:button];
    self.buttonPlay = button;
    
    UIButton *buttonStop = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
    buttonStop.center = CGPointMake(self.view.bounds.size.width / 2, 400 / 2 + self.view.bounds.size.width * 9 / 16);
    [buttonStop setTitle:@"停止" forState:(UIControlStateNormal)];
    buttonStop.backgroundColor = [UIColor blackColor];
    [buttonStop addTarget:self action:@selector(stopVideo) forControlEvents:(UIControlEventTouchUpInside)];
    [self.view addSubview:buttonStop];
    
    float y = buttonStop.frame.origin.y + buttonStop.frame.size.height + 10;
    UILabel *labelCurrentTime = [[UILabel alloc] initWithFrame:CGRectMake(10, y, 80, 20)];
    labelCurrentTime.text = @"00:00:00";
    labelCurrentTime.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:labelCurrentTime];
    self.lableCurrentTime = labelCurrentTime;
    
    UILabel *labeTotalTime = [[UILabel alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 80 - 10, y, 80, 20)];
    labeTotalTime.text = @"00:00:00";
    labeTotalTime.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:labeTotalTime];
    self.lableTotalTime = labeTotalTime;
    
    UISlider *sliderProgress = [[UISlider alloc] initWithFrame:CGRectMake(10 + 80, y, self.view.bounds.size.width - 2 * (10 + 80), 20)];
    [self.view addSubview:sliderProgress];
    self.sliderProgress = sliderProgress;
    
    [sliderProgress addTarget:self action:@selector(didSliderTouchDown) forControlEvents:UIControlEventTouchDown];
    [sliderProgress addTarget:self action:@selector(didSliderTouchCancel) forControlEvents:UIControlEventTouchCancel];
    [sliderProgress addTarget:self action:@selector(didSliderTouchUpOutside) forControlEvents:UIControlEventTouchUpOutside];
    [sliderProgress addTarget:self action:@selector(didSliderTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
    [sliderProgress addTarget:self action:@selector(didSliderValueChanged) forControlEvents:UIControlEventValueChanged];
    
}

- (void)initPlayer{
    if (!self.player) {
        IJKFFOptions *options = [IJKFFOptions optionsByDefault];
        // 静音设置
        //[options setPlayerOptionValue:@"1" forKey:@"an"];
        // 设置播放前的探测时间 1,达到首屏秒开效果
        [options setFormatOptionIntValue:1 forKey:@"analyzeduration"];
        // 帧速率（fps）可以改，确认非标准帧率会导致音画不同步，所以只能设定为15或者29.97）
        [options setPlayerOptionIntValue:29.97 forKey:@"r"];
        // 设置音量大小，256为标准音量。（要设置成两倍音量时则输入512，依此类推)
        [options setPlayerOptionIntValue:512 forKey:@"vol"];
        // 最大fps
        [options setPlayerOptionIntValue:30 forKey:@"max-fps"];
        // 跳帧开关，默认为1
        // 跳帧开关，如果cpu解码能力不足，可以设置成5，否则会引起音视频不同步，也可以通过设置它来跳帧达到倍速播放
        [options setPlayerOptionIntValue:5 forKey:@"framedrop"];
        // 开启硬编码 （默认是 0 ：软解）
        [options setPlayerOptionIntValue:1 forKey:@"videotoolbox"];
        // h265硬解
        //[options setPlayerOptionIntValue:1 forKey:@"mediacodec-hevc"];
        // 指定最大宽度
        [options setPlayerOptionIntValue:960 forKey:@"videotoolbox-max-frame-width"];
        // 自动转屏开关
        [options setFormatOptionIntValue:0 forKey:@"auto_convert"];
        // 重连开启 BOOL
        [options setFormatOptionIntValue:1 forKey:@"reconnect"];
        // 超时时间，timeout参数只对http设置有效，若果你用rtmp设置timeout，ijkplayer内部会忽略timeout参数。
        //rtmp的timeout参数含义和http的不一样。
        [options setFormatOptionIntValue:30 * 1000 * 1000 forKey:@"timeout"];
        // 如果使用rtsp协议，可以优先用tcp（默认udp）
        [options setFormatOptionValue:@"tcp" forKey:@"rtsp_transport"];
        // 播放前的探测Size，默认是1M, 改小一点会出画面更快
        [options setFormatOptionIntValue:1024 * 16 forKey:@"probesize"];
        //解码参数，画面更清晰
        // 开启环路滤波（0比48清楚，但解码开销大，48基本没有开启环路滤波，清晰度低，解码开销小）
        [options setCodecOptionIntValue:IJK_AVDISCARD_DEFAULT forKey:@"skip_loop_filter"];
        // 跳帧
        [options setCodecOptionIntValue:IJK_AVDISCARD_DEFAULT forKey:@"skip_frame"];
        // 关闭播放器缓冲 (如果频繁卡顿，可以保留缓冲区，不设置默认为1)
        //[options setPlayerOptionIntValue:0 forKey:@"packet-buffering"];
        
        // param for living
        // 最大缓存大小是3秒，可以依据自己的需求修改
        [options setPlayerOptionIntValue:3000 forKey:@"max_cached_duration"];
        // 无限读
        [options setPlayerOptionIntValue:1 forKey:@"infbuf"];
        // 关闭播放器缓冲
        [options setPlayerOptionIntValue:0 forKey:@"packet-buffering"];
        
        //param for playback
    //    [options setPlayerOptionIntValue:0 forKey:@"max_cached_duration"];
    //    [options setPlayerOptionIntValue:0 forKey:@"infbuf"];
    //    [options setPlayerOptionIntValue:1 forKey:@"packet-buffering"];
        
        _player = [[IJKFFMoviePlayerController alloc] initWithContentURL:self.url withOptions:options];
//        [_player setShouldAutoplay:NO] ;//不自动播放
        UIView *playerView = [self.player view];
        playerView.frame = self.playerView.bounds;
        //playerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.playerView insertSubview:playerView atIndex:1];
        [_player setScalingMode:IJKMPMovieScalingModeAspectFill];
        [self installMovieNotificationObservers];
        
        //添加自定义的Button到视频画面上
        self.touchButton = [[TouchButton alloc] initWithFrame:self.playerView.bounds];
        self.touchButton.touchDelegate = self;
        [self.playerView addSubview:self.touchButton];
        self.volumeView.frame = CGRectMake(0, 0, self.view.frame.size.width, 20);
        self.volumeView.backgroundColor = UIColor.redColor;
        //[self.playerView addSubview:self.volumeView];
    }
    
}

- (void)playVideo{
    if (![self.player isPlaying]) {
        if (_isStop) {
            [self initPlayer];
            [self.player prepareToPlay];
        }
        [self.player play];
//        _isPlay = YES;
    }else{
        [self.player pause];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshMediaControl) object:nil];
//        _isPlay = NO;

    }
}

- (void)stopVideo{
//    if ([self.player isPlaying]) {
        [self.player stop];
        [self releasePlayer];
        [self.buttonPlay setTitle:@"播放" forState:UIControlStateNormal];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshMediaControl) object:nil];
        _isStop = YES;
        
//    }
    
}

- (void)didSliderTouchDown
{
    _isMediaSliderBeingDragged = YES;
}

- (void)didSliderTouchCancel
{
    _isMediaSliderBeingDragged = NO;
}

- (void)didSliderTouchUpOutside
{
    _isMediaSliderBeingDragged = NO;
}

- (void)didSliderTouchUpInside
{
    self.player.currentPlaybackTime = self.sliderProgress.value;
    _isMediaSliderBeingDragged = NO;
}

- (void)didSliderValueChanged
{
    //NSLog(@"didSliderValueChanged");
    //[self refreshMediaControl];
}


-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self initPlayer];
    if (![self.player isPlaying]) {
        [self.player prepareToPlay];
    }
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    if ([self.player isPlaying]) {
        [self.player stop];
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshMediaControl) object:nil];
}

- (void)releasePlayer{
    [self.player shutdown];
    [self.player.view removeFromSuperview];
    self.player = nil;
}

- (void)dealloc{
    NSLog(@"-----dealloc");
    [self releasePlayer];
}

#pragma mark - 注册通知 Notifiacation

- (void)installMovieNotificationObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loadStateDidChange:)
                                                 name:IJKMPMoviePlayerLoadStateDidChangeNotification
                                               object:_player];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackFinish:)
                                                 name:IJKMPMoviePlayerPlaybackDidFinishNotification
                                               object:_player];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mediaIsPreparedToPlayDidChange:)
                                                 name:IJKMPMediaPlaybackIsPreparedToPlayDidChangeNotification
                                               object:_player];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackStateDidChange:)
                                                 name:IJKMPMoviePlayerPlaybackStateDidChangeNotification
                                               object:_player];
    
}

- (void)removeMovieNotificationObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IJKMPMoviePlayerLoadStateDidChangeNotification
                                                  object:_player];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IJKMPMoviePlayerPlaybackDidFinishNotification
                                                  object:_player];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IJKMPMediaPlaybackIsPreparedToPlayDidChangeNotification
                                                  object:_player];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IJKMPMoviePlayerPlaybackStateDidChangeNotification
                                                  object:_player];
    
}

#pragma mark - 通知回调方法

- (void)loadStateDidChange:(NSNotification*)notification {
    IJKMPMovieLoadState loadState = _player.loadState;
    
    if ((loadState & IJKMPMovieLoadStatePlaythroughOK) != 0) {
        NSLog(@"LoadStateDidChange: IJKMovieLoadStatePlayThroughOK: %d\n",(int)loadState);
    }else if ((loadState & IJKMPMovieLoadStateStalled) != 0) {
        NSLog(@"loadStateDidChange: IJKMPMovieLoadStateStalled: %d\n", (int)loadState);
    } else {
        NSLog(@"loadStateDidChange: ???: %d\n", (int)loadState);
    }
}

- (void)moviePlayBackFinish:(NSNotification*)notification {
    int reason =[[[notification userInfo] valueForKey:IJKMPMoviePlayerPlaybackDidFinishReasonUserInfoKey] intValue];
    switch (reason) {
        case IJKMPMovieFinishReasonPlaybackEnded:
            NSLog(@"playbackStateDidChange: IJKMPMovieFinishReasonPlaybackEnded: %d\n", reason);
            break;
            
        case IJKMPMovieFinishReasonUserExited:
            NSLog(@"playbackStateDidChange: IJKMPMovieFinishReasonUserExited: %d\n", reason);
            break;
            
        case IJKMPMovieFinishReasonPlaybackError:
            NSLog(@"playbackStateDidChange: IJKMPMovieFinishReasonPlaybackError: %d\n", reason);
            break;
            
        default:
            NSLog(@"playbackPlayBackDidFinish: ???: %d\n", reason);
            break;
    }
}

- (void)mediaIsPreparedToPlayDidChange:(NSNotification*)notification {
    NSLog(@"mediaIsPrepareToPlayDidChange\n");
}

- (void)moviePlayBackStateDidChange:(NSNotification*)notification {
    switch (_player.playbackState) {
        case IJKMPMoviePlaybackStateStopped:
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: stoped", (int)_player.playbackState);
            [self.buttonPlay setTitle:@"播放" forState:UIControlStateNormal];
            break;
            
        case IJKMPMoviePlaybackStatePlaying:
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: playing", (int)_player.playbackState);
            [self.buttonPlay setTitle:@"暂停" forState:UIControlStateNormal];
            [self refreshMediaControl];
            break;
            
        case IJKMPMoviePlaybackStatePaused:
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: paused", (int)_player.playbackState);
            [self.buttonPlay setTitle:@"播放" forState:UIControlStateNormal];
//            if (_isPlay) {
//                [self.player play];
//            }
            break;
            
        case IJKMPMoviePlaybackStateInterrupted:
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: interrupted", (int)_player.playbackState);
            break;
            
        case IJKMPMoviePlaybackStateSeekingForward:
        case IJKMPMoviePlaybackStateSeekingBackward: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: seeking", (int)_player.playbackState);
            [self.buttonPlay setTitle:@"暂停" forState:UIControlStateNormal];
            break;
        }
            
        default: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: unknown", (int)_player.playbackState);
            break;
        }
    }
}

#pragma mark - 刷新时间跟progress
- (void)refreshMediaControl{
    // duration
    NSTimeInterval duration = self.player.duration;
    NSInteger intDuration = duration + 0.5;
    if (intDuration > 0) {
        self.sliderProgress.maximumValue = duration;
        self.lableTotalTime.text = [self timeformatFromSeconds:intDuration];
    } else {
        self.lableTotalTime.text = @"--:--:--";
        self.sliderProgress.maximumValue = 1.0f;
    }
    
    // position
    NSTimeInterval position;
    if (_isMediaSliderBeingDragged) {
        position = self.sliderProgress.value;
    } else {
        position = self.player.currentPlaybackTime;
    }
    NSInteger intPosition = position + 0.5;
    if (intDuration > 0) {
        self.sliderProgress.value = position;
    } else {
        self.sliderProgress.value = 0.0f;
    }
    self.lableCurrentTime.text = [self timeformatFromSeconds:intPosition];;
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshMediaControl) object:nil];
//    if (!self.overlayPanel.hidden) {
        [self performSelector:@selector(refreshMediaControl) withObject:nil afterDelay:0.5];
//    }


}

// 时间格式
- (NSString*)timeformatFromSeconds:(NSInteger)seconds
{
    //format of hour
    NSString *str_hour = [NSString stringWithFormat:@"%02ld",seconds/3600];
    //format of minute
    NSString *str_minute = [NSString stringWithFormat:@"%02ld",(seconds%3600)/60];
    //format of second
    NSString *str_second = [NSString stringWithFormat:@"%02ld",seconds%60];
    //format of time
    NSString *format_time = [NSString stringWithFormat:@"%@:%@:%@",str_hour,str_minute,str_second];
    return format_time;
}

#pragma mark - TouchButtonDelegate代理
- (void)touchesBeganWithPoint:(CGPoint)point {
    //NSLog(@"touchesBeganWithPoint");
    //记录首次触摸坐标
    self.startPoint = point;
    //检测用户是触摸屏幕的左边还是右边，以此判断用户是要调节音量还是亮度，左边是亮度，右边是音量
    if (self.startPoint.x <= self.touchButton.frame.size.width / 2.0) {
        //亮度
        self.startVB = [UIScreen mainScreen].brightness;
    } else {
        //音量
        self.startVB = self.volumeViewSlider.value;
    }
    //方向置为无
    self.direction = DirectionNone;
    //记录当前视频播放的进度
    self.startVideoRate = self.player.currentPlaybackTime / self.player.duration;
    
}

- (void)touchesEndWithPoint:(CGPoint)point {
    if (self.direction == DirectionLeftOrRight) {
        self.player.currentPlaybackTime = self.currentRate * self.player.duration;
    }
}

- (void)touchesMoveWithPoint:(CGPoint)point {
    //得出手指在Button上移动的距离
    CGPoint panPoint = CGPointMake(point.x - self.startPoint.x, point.y - self.startPoint.y);
    //分析出用户滑动的方向
    if (self.direction == DirectionNone) {
        if (panPoint.x >= 30 || panPoint.x <= -30) {
            //进度
            self.direction = DirectionLeftOrRight;
        } else if (panPoint.y >= 30 || panPoint.y <= -30) {
            //音量和亮度
            self.direction = DirectionUpOrDown;
        }
    }
    
    if (self.direction == DirectionNone) {
        return;
    } else if (self.direction == DirectionUpOrDown) {
        //音量和亮度
        if (self.startPoint.x <= self.touchButton.frame.size.width / 2.0) {
            //调节亮度
            if (panPoint.y < 0) {
                //增加亮度
                [[UIScreen mainScreen] setBrightness:self.startVB + (-panPoint.y / 30.0 / 10)];
            } else {
                //减少亮度
                [[UIScreen mainScreen] setBrightness:self.startVB - (panPoint.y / 30.0 / 10)];
            }
            
        } else {
            //音量
            if (panPoint.y < 0) {
                //增大音量
                [self.volumeViewSlider setValue:self.startVB + (-panPoint.y / 30.0 / 10) animated:YES];
                if (self.startVB + (-panPoint.y / 30 / 10) - self.volumeViewSlider.value >= 0.1) {
                    [self.volumeViewSlider setValue:0.1 animated:NO];
                    [self.volumeViewSlider setValue:self.startVB + (-panPoint.y / 30.0 / 10) animated:YES];
                }
                
            } else {
                //减少音量
                [self.volumeViewSlider setValue:self.startVB - (panPoint.y / 30.0 / 10) animated:YES];
            }
        }
    } else if (self.direction == DirectionLeftOrRight ) {
        //进度
        CGFloat rate = self.startVideoRate + (panPoint.x / self.touchButton.bounds.size.width / 3);
        if (rate > 1) {
            rate = 1;
        } else if (rate < 0) {
            rate = 0;
        }
        self.currentRate = rate;
    }
}

- (MPVolumeView *)volumeView {
    if (_volumeView == nil) {
        _volumeView  = [[MPVolumeView alloc] init];
        [_volumeView sizeToFit];
        for (UIView *view in [_volumeView subviews]){
            if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
                self.volumeViewSlider = (UISlider*)view;
                break;
            }
        }
    }
    return _volumeView;
}

@end
