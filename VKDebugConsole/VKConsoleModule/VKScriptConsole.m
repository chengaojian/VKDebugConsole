//
//  VKDebugConsole.m
//  VKDebugConsole
//
//  Created by Awhisper on 16/5/20.
//  Copyright © 2016年 baidu. All rights reserved.
//

#import "VKScriptConsole.h"
#import "VKCommonFundation.h"
#import "VKJPEngine.h"
#import "VKLogManager.h"
#import "NSMutableAttributedString+VKAttributedString.h"
static CGFloat maskAlpha = 0.6f;

@interface VKScriptConsole ()<UITextViewDelegate>


@property (nonatomic,strong) UIView *mask;

@property (nonatomic,strong) UITextView *inputView;

@property (nonatomic,strong) UITextView *outputView;

@end

@implementation VKScriptConsole


#pragma mark construct

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.mask.alpha = 0;
        [self startScriptEngine];
    }
    return self;
}


-(void)setTarget:(id)target
{
    _target = target;
    [VKJPEngine setScriptWeakTarget:_target];
}

-(void)startScriptEngine
{
    [VKJPEngine startEngine];
    [VKJPEngine setScriptWeakTarget:self.target];
    __weak typeof(self) weakSelf = self;
    [VKJPEngine handleException:^(NSString *msg) {
        [weakSelf addScriptLogToOutput:msg WithUIColor:[UIColor redColor]];
    }];
    
    [VKJPEngine handleLog:^(NSString *msg) {
        [weakSelf addScriptLogToOutput:msg WithUIColor:[UIColor yellowColor]];
    }];
    
    [VKJPEngine handleCommand:^(NSString *command) {
        if ([command isEqualToString:@"changeSelect"]) {
            [weakSelf.delegate VKScriptConsoleExchangeTargetAction];
        }
        
        if ([command isEqualToString:@"exit"]) {
            [weakSelf.delegate VKScriptConsoleExitAction];
        }
        
        if ([command isEqualToString:@"clearInput"]) {
            weakSelf.inputView.text = @"";
        }
        
        if ([command isEqualToString:@"clearOutput"]) {
            weakSelf.outputView.text = @"";
        }
    }];
}

-(UIView *)mask
{
    if (!_mask) {
        UIView *maskv = [[UIView alloc]initWithFrame:self.bounds];
        maskv.backgroundColor = [UIColor blackColor];
        maskv.alpha = maskAlpha;
        _mask = maskv;
        [self addSubview:maskv];
    }
    return _mask;
}

-(UITextView *)inputView
{
    if (!_inputView) {
        UITextView * input = [[UITextView alloc]initWithFrame:CGRectMake(0, 20, self.width, self.height/3)];
        _inputView = input;
        input.textColor = [UIColor yellowColor];
        input.layer.borderWidth = 1;
        input.layer.borderColor = [UIColor blackColor].CGColor;
        input.delegate = self;
        input.backgroundColor = [UIColor clearColor];
        [self addSubview:input];
    }
    return _inputView;
}

-(UITextView *)outputView
{
    if (!_outputView) {
        UITextView * output = [[UITextView alloc]initWithFrame:CGRectMake(0, self.height/3 + 20, self.width, self.height*2/3 - 20)];
        _outputView = output;
        output.textColor = [UIColor yellowColor];
        [self addSubview:output];
        output.backgroundColor = [UIColor clearColor];
        output.text = @"output:";
    }
    return _outputView;
}

-(void)showConsole
{
    self.alpha = 0;
    self.inputView.text = @"";
    self.outputView.text = @"output:";
    [UIView animateWithDuration:0.5f animations:^{
        self.alpha = 1;
        self.mask.alpha = maskAlpha;
        self.inputView.alpha = 1;
        self.outputView.alpha = 1;
    } completion:^(BOOL finished) {
        [self addLogNotificationObserver];
        [self showLogManagerOldLog];
    }];
    
}

-(void)hideConsole
{
    [UIView animateWithDuration:1.0f animations:^{
        self.alpha = 0;
        self.mask.alpha = 0;
        self.inputView.alpha = 0;
        self.outputView.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        [self removeLogNotificationObserver];
    }];
}

#pragma mark log logic
-(void)showLogManagerOldLog
{
    for (NSString * log in [VKLogManager singleton].logDataArray) {
        if ([log rangeOfString:@"NSLog: "].location != NSNotFound) {
            [self addScriptLogToOutput:log WithUIColor:[UIColor whiteColor]];
        }else if ([log rangeOfString:@"NSError: "].location != NSNotFound){
            [self addScriptLogToOutput:log WithUIColor:[UIColor redColor]];
        }
    }
}

-(void)addLogNotificationObserver
{
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(logNotificationGet:) name:VKLogNotification object:nil];
}

-(void)removeLogNotificationObserver
{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

-(void)logNotificationGet:(NSNotification *)noti
{
    NSString * log = noti.object;
    if ([log rangeOfString:@"NSLog: "].location != NSNotFound) {
        [self addScriptLogToOutput:log WithUIColor:[UIColor whiteColor]];
    }else if ([log rangeOfString:@"NSError: "].location != NSNotFound){
        [self addScriptLogToOutput:log WithUIColor:[UIColor redColor]];
    }

}


-(void)addScriptLogToOutput:(NSString *)log WithUIColor:(UIColor *)color{
    NSAttributedString *txt = self.outputView.attributedText;
    NSMutableAttributedString *mtxt = [[NSMutableAttributedString alloc]initWithAttributedString:txt];
    NSAttributedString *huanhang = [[NSAttributedString alloc]initWithString:@"\n"];
    [mtxt appendAttributedString:huanhang];
    
    NSMutableAttributedString *logattr = [[NSMutableAttributedString alloc]initWithString:log];
    [logattr vk_setTextColor:color];
    [mtxt appendAttributedString:logattr];
    self.outputView.attributedText = mtxt;
    
    if (self.outputView.contentSize.height > self.outputView.frame.size.height) {
        [self.outputView setContentOffset:CGPointMake(0.f,self.outputView.contentSize.height-self.outputView.frame.size.height)];
    }
}
#pragma mark logic delegate
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text{
    if ([text isEqualToString:@"\n"]){ //判断输入的字是否是回车，即按下return
        //在这里做你响应return键的代码
//        self.outputView.text = @"output:";
        [VKJPEngine evaluateScript:textView.text];
        
        return YES;
    }
    
    return YES;
}

-(void)setInputCode:(NSString *)code
{
    self.inputView.text = code;
}

@end
