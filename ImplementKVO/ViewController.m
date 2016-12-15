//
//  ViewController.m
//  ImplementKVO
//
//  Created by Peng Gu on 2/26/15.
//  Copyright (c) 2015 Peng Gu. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+KVO.h"

#pragma People - class
@interface People : NSObject
//{
//@public
//    NSString* age;
//}
@property (nonatomic, copy) NSString *age;

@end
@implementation People
@end

#pragma Message - class
@interface Message : NSObject{
@public
    NSString* msg;
    People* people;
}
@property (nonatomic, copy) NSString *info;
//@property (nonatomic,strong) People* people;

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
    [me PG_addObserver:self forKeyPath:@"msg" withBlock:^(id observedObject, NSString *observedKey, id oldValue, id newValue) {
        NSLog(@"%@: newValue = %@ oldValue = %@",observedKey,newValue,oldValue);
    }];
    [me PG_addObserver:self forKeyPath:@"info" withBlock:^(id observedObject, NSString *observedKey, id oldValue, id newValue) {
        NSLog(@"%@: newValue = %@  oldValue = %@",observedKey,newValue,oldValue);
    }];
    [me PG_addObserver:self forKeyPath:@"people.age" withBlock:^(id observedObject, NSString *observedKey, id oldValue, id newValue) {
        NSLog(@"%@: newValue = %@  oldValue = %@",observedKey,newValue,oldValue);
    }];
    People* people = [[People alloc] init];
    //me->people = people;
    [me setValue:people forKey:@"people"];
    _message = me;
}





- (IBAction)KVOAction:(id)sender {
    [_message setValue:@"黄芝标" forKey:@"msg"];
    [_message setValue:@"100" forKey:@"info"];
    _message.info = @"55";
    //_message.people.age = @"100岁";
    [_message setValue:@"100岁" forKeyPath:@"people.age"];
    [_message PG_removeObserver:self forKeyPath:@"msg"];
    [_message PG_removeObserver:self forKeyPath:@"info"];
    [_message PG_removeObserver:self forKeyPath:@"people.age"];
//    [_message PG_addObserver:self forKeyPath:@"people.age" withBlock:^(id observedObject, NSString *observedKey, id oldValue, id newValue) {
//        NSLog(@"%@: newValue = %@  oldValue = %@",observedKey,newValue,oldValue);
//    }];
}
@end
