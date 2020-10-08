//
//  IJKPlayerViewController.m
//  IJKPlayerTest
//
//  Created by Myron on 2020/10/6.
//

#import "IJKPlayerViewController.h"
#import <IJKMediaFramework/IJKMediaFramework.h>



@interface IJKPlayerViewController ()

@property(atomic, strong) NSURL *url;
@property(atomic, retain) id <IJKMediaPlayback> player;
@property(nonatomic,weak) UIView *PlayerView;
@property(nonatomic,weak) UIButton *button;
@property(nonatomic,weak) UILabel *lableCurrentTime;
@property(nonatomic,weak) UILabel *lableTotalTime;
@property(nonatomic,weak) UISlider *sliderProgress;


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
    
    UIView *displayView = [[UIView alloc] initWithFrame:CGRectMake(0, 50, self.view.bounds.size.width, self.view.bounds.size.width * 9 / 16)];
    self.PlayerView = displayView;
    self.PlayerView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.PlayerView];
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
    button.center = CGPointMake(self.view.bounds.size.width / 2, 200 / 2 + self.view.bounds.size.width * 9 / 16);
    [button setTitle:@"播放" forState:(UIControlStateNormal)];
    button.backgroundColor = [UIColor blackColor];
    [button addTarget:self action:@selector(playVideo) forControlEvents:(UIControlEventTouchUpInside)];
    [self.view addSubview:button];
    self.button = button;
    
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
        playerView.frame = self.PlayerView.bounds;
        playerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.PlayerView insertSubview:playerView atIndex:1];
        [_player setScalingMode:IJKMPMovieScalingModeAspectFill];
        [self installMovieNotificationObservers];
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
        [self.button setTitle:@"播放" forState:UIControlStateNormal];
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
            [self.button setTitle:@"播放" forState:UIControlStateNormal];
            break;
            
        case IJKMPMoviePlaybackStatePlaying:
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: playing", (int)_player.playbackState);
            [self.button setTitle:@"暂停" forState:UIControlStateNormal];
            [self refreshMediaControl];
            break;
            
        case IJKMPMoviePlaybackStatePaused:
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: paused", (int)_player.playbackState);
            [self.button setTitle:@"播放" forState:UIControlStateNormal];
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
            [self.button setTitle:@"暂停" forState:UIControlStateNormal];
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



@end
