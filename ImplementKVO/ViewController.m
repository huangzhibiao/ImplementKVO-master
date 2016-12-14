//
//  ViewController.m
//  ImplementKVO
//
//  Created by Peng Gu on 2/26/15.
//  Copyright (c) 2015 Peng Gu. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+KVO.h"

@interface Message : NSObject
{
@public
    NSString* msg;
}


@property (nonatomic, copy) NSString *name;

@end

@implementation Message

@end



@interface ViewController ()

@property (nonatomic, strong) Message *message;


- (IBAction)KVOAction:(id)sender;

@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    Message* me = [[Message alloc] init];
    [me PG_addObserver:self forKey:@"msg" withBlock:^(id observedObject, NSString *observedKey, id oldValue, id newValue) {
        NSLog(@"%@: newValue = %@ oldValue = %@",observedKey,newValue,oldValue);
    }];
    [me PG_addObserver:self forKey:@"name" withBlock:^(id observedObject, NSString *observedKey, id oldValue, id newValue) {
        NSLog(@"%@: newValue = %@  oldValue = %@",observedKey,newValue,oldValue);
    }];

    _message = me;
}





- (IBAction)KVOAction:(id)sender {
    [_message setValue:@"黄芝标" forKey:@"msg"];
    [_message setValue:@"100" forKey:@"name"];
    _message.name = @"55";
}
@end
