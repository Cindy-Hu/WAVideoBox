//
//  WAAVSECommand.m
//  WA
//
//  Created by 黄锐灏 on 2017/8/14.
//  Copyright © 2017年 黄锐灏. All rights reserved.
//

#import "WAAVSECommand.h"

@interface WAAVSECommand ()

@property (nonatomic , strong) AVAssetTrack *assetVideoTrack;

@property (nonatomic , strong) AVAssetTrack *assetAudioTrack;

@property (nonatomic , assign) NSInteger trackDegress;

@end

@implementation WAAVSECommand

- (instancetype)init{
    return [self initWithComposition:[WAAVSEComposition new]];
}

- (instancetype)initWithComposition:(WAAVSEComposition *)composition{
    self = [super init];
    if(self != nil) {
        self.composition = composition;
    }
    return self;
}


- (void)performWithAsset:(AVAsset *)asset
{
    
    // 1.1､视频资源的轨道
    if (!self.assetVideoTrack) {
        if ([asset tracksWithMediaType:AVMediaTypeVideo].count != 0) {
            self.assetVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
        }
    }
    
    // 1.2､音频资源的轨道
    if (!self.assetAudioTrack) {
        if ([asset tracksWithMediaType:AVMediaTypeAudio].count != 0) {
            self.assetAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
        }
    }
    
    // 2､创建混合器
  
    if(!self.composition.mutableComposition) {
        
        // 要混合的时间
        CMTime insertionPoint = kCMTimeZero;
        NSError *error = nil;
        
        self.composition.mutableComposition = [AVMutableComposition composition];
        //  2.1､把视频轨道加入到混合器做出新的轨道
        if (self.assetVideoTrack != nil) {
            
            AVMutableCompositionTrack *compostionVideoTrack = [self.composition.mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
            
            [compostionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration]) ofTrack:self.assetVideoTrack atTime:insertionPoint error:&error];

            self.composition.duration = self.composition.mutableComposition.duration;
            
            self.trackDegress = [self degressFromTransform:self.assetVideoTrack.preferredTransform];
           
            if (self.trackDegress % 360) {
                [self performVideoCompopsition];
            }else{
                self.composition.mutableComposition.naturalSize = compostionVideoTrack.naturalSize;
            }
            
        }
        
        //  2.2､把音频轨道加入到混合器做出新的轨道
        if (self.assetAudioTrack != nil) {
            
            AVMutableCompositionTrack *compositionAudioTrack = [self.composition.mutableComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        
            [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration]) ofTrack:self.assetAudioTrack atTime:insertionPoint error:&error];
        }
        
    }
    
}

- (void)performVideoCompopsition{
   
    if(!self.composition.mutableVideoComposition) {
        
        self.composition.mutableVideoComposition = [AVMutableVideoComposition videoComposition];
        self.composition.mutableVideoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
        self.composition.mutableVideoComposition.renderSize = self.assetVideoTrack.naturalSize;
    
        
        AVMutableVideoCompositionInstruction *passThroughInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        passThroughInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, [self.composition.mutableComposition duration]);

        AVAssetTrack *videoTrack = [self.composition.mutableComposition tracksWithMediaType:AVMediaTypeVideo][0];

        AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        [passThroughLayer setTransform:self.assetVideoTrack.preferredTransform atTime:kCMTimeZero];
        passThroughInstruction.layerInstructions = @[passThroughLayer];
        
        [self.composition.instructions addObject:passThroughInstruction];
        self.composition.mutableVideoComposition.instructions = self.composition.instructions;
        
        if (self.trackDegress == 90 || self.trackDegress == 270) {
              self.composition.mutableVideoComposition.renderSize = CGSizeMake(self.assetVideoTrack.naturalSize.height, self.assetVideoTrack.naturalSize.width);
        }
        
        self.composition.lastInstructionSize = self.composition.mutableComposition.naturalSize  = self.composition.mutableVideoComposition.renderSize;
        
    }

}

- (void)performAudioCompopsition{
    if (!self.composition.mutableAudioMix) {
        
        self.composition.mutableAudioMix = [AVMutableAudioMix audioMix];
        
        for (AVMutableCompositionTrack *compostionVideoTrack in [self.composition.mutableComposition tracksWithMediaType:AVMediaTypeAudio]) {
      
            AVMutableAudioMixInputParameters *audioParam = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:compostionVideoTrack];
            [audioParam setVolume:1.0 atTime:kCMTimeZero];
            [self.composition.audioMixParams addObject:audioParam];
        }
        self.composition.mutableAudioMix.inputParameters = self.composition.audioMixParams;
    }
}


- (void)performWithAsset:(AVAsset *)asset degress:(NSUInteger)degress{
    
    [self performVideoCompopsition];
    
    AVMutableVideoCompositionInstruction *instruction = nil;
    AVMutableVideoCompositionLayerInstruction *layerInstruction = nil;
    CGAffineTransform t1;
    CGAffineTransform t2;
    CGSize renderSize;
    
    // 角度调整
    degress -= degress % 360 % 90;
   
    if (degress == 90) {
        t1 = CGAffineTransformMakeTranslation(self.composition.mutableVideoComposition.renderSize.height, 0.0);
        renderSize = CGSizeMake(self.composition.mutableVideoComposition.renderSize.height, self.composition.mutableVideoComposition.renderSize.width);
    }else if (degress == 180){
        t1 = CGAffineTransformMakeTranslation(self.composition.mutableVideoComposition.renderSize.width, self.composition.mutableVideoComposition.renderSize.height);
        renderSize = CGSizeMake(self.composition.mutableVideoComposition.renderSize.width, self.composition.mutableVideoComposition.renderSize.height);
    }else if (degress == 270){
        t1 = CGAffineTransformMakeTranslation(0.0, self.composition.mutableVideoComposition.renderSize.width);
        renderSize = CGSizeMake(self.composition.mutableVideoComposition.renderSize.height, self.composition.mutableVideoComposition.renderSize.width);
    }else{
        t1 = CGAffineTransformMakeTranslation(0.0, 0.0);
        renderSize = CGSizeMake(self.composition.mutableVideoComposition.renderSize.width, self.composition.mutableVideoComposition.renderSize.height);
    }
    
    // Rotate transformation
    t2 = CGAffineTransformRotate(t1, (degress / 180.0) * M_PI );
   
    self.composition.mutableComposition.naturalSize = self.composition.mutableVideoComposition.renderSize = renderSize;
    
    instruction = (AVMutableVideoCompositionInstruction *)(self.composition.mutableVideoComposition.instructions)[0];
    layerInstruction = (AVMutableVideoCompositionLayerInstruction *)(instruction.layerInstructions)[0];
    
    CGAffineTransform existingTransform;
    
    if (![layerInstruction getTransformRampForTime:[self.composition.mutableComposition duration] startTransform:&existingTransform endTransform:NULL timeRange:NULL]) {
        [layerInstruction setTransform:t2 atTime:kCMTimeZero];
    } else {
        CGAffineTransform newTransform =  CGAffineTransformConcat(existingTransform, t2);
        [layerInstruction setTransform:newTransform atTime:kCMTimeZero];
    }
    
    instruction.layerInstructions = @[layerInstruction];
    self.composition.mutableVideoComposition.instructions = @[instruction];
    
}

- (NSUInteger)degressFromTransform:(CGAffineTransform)transForm
{
    NSUInteger degress = 0;
    
    if(transForm.a == 0 && transForm.b == 1.0 && transForm.c == -1.0 && transForm.d == 0){
        // Portrait
        degress = 90;
    }else if(transForm.a == 0 && transForm.b == -1.0 && transForm.c == 1.0 && transForm.d == 0){
        // PortraitUpsideDown
        degress = 270;
    }else if(transForm.a == 1.0 && transForm.b == 0 && transForm.c == 0 && transForm.d == 1.0){
        // LandscapeRight
        degress = 0;
    }else if(transForm.a == -1.0 && transForm.b == 0 && transForm.c == 0 && transForm.d == -1.0){
        // LandscapeLeft
        degress = 180;
    }
    
    return degress;
}


NSString *const WAAVSEExportCommandCompletionNotification = @"WAAVSEExportCommandCompletionNotification";
NSString* const WAAVSEExportCommandError = @"WAAVSEExportCommandError";

@end
