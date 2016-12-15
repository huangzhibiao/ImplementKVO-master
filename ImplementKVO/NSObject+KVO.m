//
//  NSObject+KVO.m
//  ImplementKVO
//
//  Created by Peng Gu on 2/26/15.
//  Copyright (c) 2015 Peng Gu. All rights reserved.
//

#import "NSObject+KVO.h"
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *const kPGKVOClassPrefix = @"PGKVOClassPrefix_";
static NSString *const kPGKVOAssociatedObservers = @"PGKVOAssociatedObservers";
static NSString *const kPGKVOAssociatedPGObservationInfo = @"PGKVOAssociatedPGObservationInfo";


#pragma mark - PGObservationInfo
@interface PGObservationInfo : NSObject{
    @package
    IMP method;
}


@property (nonatomic, weak) NSObject *observer;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) PGObservingBlock block;

@end

@implementation PGObservationInfo

- (instancetype)initWithObserver:(NSObject *)observer Key:(NSString *)key block:(PGObservingBlock)block
{
    self = [super init];
    if (self) {
        _observer = observer;
        _key = key;
        _block = block;
    }
    return self;
}

@end


#pragma mark - Debug Help Methods
static NSArray *ClassMethodNames(Class c)
{
    NSMutableArray *array = [NSMutableArray array];
    
    unsigned int methodCount = 0;
    Method *methodList = class_copyMethodList(c, &methodCount);
    unsigned int i;
    for(i = 0; i < methodCount; i++) {
        [array addObject: NSStringFromSelector(method_getName(methodList[i]))];
    }
    free(methodList);
    
    return array;
}


static void PrintDescription(NSString *name, id obj)
{
    NSString *str = [NSString stringWithFormat:
                     @"%@: %@\n\tNSObject class %s\n\tRuntime class %s\n\timplements methods <%@>\n\n",
                     name,
                     obj,
                     class_getName([obj class]),
                     class_getName(object_getClass(obj)),
                     [ClassMethodNames(object_getClass(obj)) componentsJoinedByString:@", "]];
    printf("%s\n", [str UTF8String]);
}


#pragma mark - Helpers
/**
 原作者在这里通过set函数字符串获取get函数字符串有个bug(没有考虑属性或变量是大写字母开头的情况),我已经修复了,您可以对比看一下
 */
static NSString * getterForSetter(id self,NSString *setter)
{
    if (setter.length <=0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]) {
        return nil;
    }
    
    // remove 'set' at the begining and ':' at the end
    NSRange range = NSMakeRange(3, setter.length - 4);
    NSString *key = [setter substringWithRange:range];
    
    // lower case the first letter
    NSString *firstLetter = [[key substringToIndex:1] lowercaseString];
    key = [key stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                       withString:firstLetter];
    //原作者这里有个bug,没有考虑属性是大写字母开头的情况,导致获取get方法错误
    if (class_getInstanceVariable(object_getClass(self),[key UTF8String])||
        class_getProperty(object_getClass(self),[key UTF8String])){
        return key;
    }else{
        return [key stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                            withString:[firstLetter uppercaseString]];
    }
    
}


static NSString * setterForGetter(NSString *getter)
{
    if (getter.length <= 0) {
        return nil;
    }
    
    // upper case the first letter
    NSString *firstLetter = [[getter substringToIndex:1] uppercaseString];
    NSString *remainingLetters = [getter substringFromIndex:1];
    
    // add 'set' at the begining and ':' at the end
    NSString *setter = [NSString stringWithFormat:@"set%@%@:", firstLetter, remainingLetters];
    
    return setter;
}

#pragma mark - Add new Methods
static void add_setter(id self, SEL _cmd, id newValue)
{
    NSString *setterName = NSStringFromSelector(_cmd);
    NSString *getterName = getterForSetter(self,setterName);
    Ivar ivar = class_getInstanceVariable([self class],[getterName UTF8String]);
    object_setIvar(self, ivar, newValue);
}

static id add_getter(id self, SEL _cmd)
{
    NSString *key = NSStringFromSelector(_cmd);
    Ivar ivar = class_getInstanceVariable([self class],[key UTF8String]);
    return object_getIvar(self,ivar);
}

//此方法用于改变setValue:forKey:方法的IMP地址,当调用setValue:forKey:函数时候回调用这个函数执行,在这里调用set函数触发KVO回调
static void setValueforKey(id self, SEL _cmd,id value,id key)
{
    SEL setterSelector = NSSelectorFromString(setterForGetter(key));
    Method setterMethod = class_getInstanceMethod([self class], setterSelector);
    if (setterMethod){//有set函数实现就调用set函数，在set函数里触发KVO
        [self performSelector:setterSelector withObject:value];
    }else{//没有实现set函数就直接赋值
        add_setter(self, setterSelector,value);
    }
}


#pragma mark - Overridden Methods
static void kvo_setter(id self, SEL _cmd, id newValue)
{
    NSString *setterName = NSStringFromSelector(_cmd);
    NSString *getterName = getterForSetter(self,setterName);
    
    if (!getterName) {
        NSString *reason = [NSString stringWithFormat:@"Object %@ does not have setter %@", self, setterName];
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
        return;
    }
    
    id oldValue = [self valueForKey:getterName];
    
    struct objc_super superclazz = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    
    // cast our pointer so the compiler won't complain
    void (*objc_msgSendSuperCasted)(void *, SEL, id) = (void *)objc_msgSendSuper;
    
    // call super's setter, which is original class's setter method
    objc_msgSendSuperCasted(&superclazz, _cmd, newValue);
    
    // look up observers and call the blocks
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(kPGKVOAssociatedObservers));
    for (PGObservationInfo *each in observers) {
        if ([each.key isEqualToString:getterName]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                each.block(self, getterName, oldValue, newValue);
            });
        }
    }
}

static void kvo_observerSetCommond(id self,id value,NSString* key){
    key = class_getProperty(object_getClass(self),[key UTF8String])?[NSString stringWithFormat:@"_%@",key]:key;
    Ivar ivar = class_getInstanceVariable(object_getClass(self),[key UTF8String]);
    object_setIvar(self, ivar, value);
    //把存储的参数值取出来
    PGObservationInfo* info = objc_getAssociatedObject(self,&kPGKVOAssociatedPGObservationInfo);
    if ([key isEqualToString:[[info.key componentsSeparatedByString:@"."] firstObject]]){
        SEL selector = NSSelectorFromString(@"setValue:forKey:");
        [self PG_addObserver:info.observer forKeyPath:info.key withBlock:info.block];
        class_replaceMethod(object_getClass(self),selector,info->method,method_getTypeEncoding(class_getClassMethod(object_getClass(self),selector)));
    }
}

static void kvo_observerSet(id self, SEL _cmd, id value){
    NSString *setterName = NSStringFromSelector(_cmd);
    NSString *getterName = getterForSetter(self,setterName);
    kvo_observerSetCommond(self,value,getterName);
}

static void kvo_observerSetValueForKey(id self, SEL _cmd, id value,id key){
    kvo_observerSetCommond(self,value,key);
}


static Class kvo_class(id self, SEL _cmd)
{
    return class_getSuperclass(object_getClass(self));
}


#pragma mark - KVO Category
@implementation NSObject (KVO)

- (void)PG_addObserver:(NSObject *)observer
                forKeyPath:(NSString *)keyPath
             withBlock:(PGObservingBlock)block
{
    //forKeyPath要做递归处理
    if ([keyPath containsString:@"."]) {
        NSArray<NSString*>* keys = [keyPath componentsSeparatedByString:@"."];
        Ivar ivar = class_getInstanceVariable(object_getClass(self),[[NSString stringWithFormat:@"_%@",keys[0]] UTF8String]);
        if (!ivar) {
            ivar = class_getInstanceVariable(object_getClass(self),[keys[0] UTF8String]);
        }
        id ob = object_getIvar(self,ivar);
        if(!ob){//为了解决属性为空时就注册监听无效的情况
            //先把各个参数值存储起来
            PGObservationInfo* info = [[PGObservationInfo alloc] initWithObserver:observer Key:keyPath block:block];
            objc_setAssociatedObject(self,&kPGKVOAssociatedPGObservationInfo,info, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            SEL Selector = NSSelectorFromString(setterForGetter(keys[0]));
            IMP selectorIMP = (IMP)kvo_observerSet;
            Method setterMethod = class_getInstanceMethod(object_getClass(self),Selector);
            if (!setterMethod){//没有set方法就重写setValue:forKey:
                Selector = NSSelectorFromString(@"setValue:forKey:");
                selectorIMP = (IMP)kvo_observerSetValueForKey;
                //先存储系统实现setValue:forKey:的IMP,后面还要替换回来
                info->method = method_getImplementation(class_getInstanceMethod(object_getClass(self),Selector));
                //NSLog(@"重写了setValue:forKey: 方法...");
            }
            //最后替换方法的IMP地址
            class_replaceMethod(object_getClass(self),Selector,selectorIMP,method_getTypeEncoding(class_getInstanceMethod(object_getClass(self),Selector)));
            return;
        }
        //递归处理
        [ob PG_addObserver:self forKeyPath:[keyPath substringFromIndex:keys[0].length+1] withBlock:block];
        //NSLog(@"里面获得的地址 = %p key = %@",ob,keyPath);
        return;
    }

    
    Class clazz = object_getClass(self);
    NSString *clazzName = NSStringFromClass(clazz);
    SEL setterSelector = NSSelectorFromString(setterForGetter(keyPath));
    Method setterMethod = class_getInstanceMethod(clazz, setterSelector);
    /**
     原作者这里不应该抛出异常,因为系统的KVO也是可以注册监听变量的(通过KVC赋值会触发,直接赋值不会触发)
     */
    if (!setterMethod) {
        //        NSString *reason = [NSString stringWithFormat:@"Object %@ does not have a setter for key %@", self, key];
        //        @throw [NSException exceptionWithName:NSInvalidArgumentException
        //                                       reason:reason
        //                                     userInfo:nil];
        //
        //        return;
        
        //给本类变量添加set函数
        class_addMethod(clazz,setterSelector,(IMP)add_setter,"v@:");
        setterMethod = class_getInstanceMethod(clazz, setterSelector);
        //改变setValue:fotKey的调用地址(也就是IMP)
        SEL setVlueSEL = NSSelectorFromString(@"setValue:forKey:");
        class_replaceMethod(clazz,setVlueSEL,(IMP)setValueforKey,method_getTypeEncoding(class_getInstanceMethod(clazz, setVlueSEL)));
    }

    
    // if not an KVO class yet
    if (![clazzName hasPrefix:kPGKVOClassPrefix]) {
        clazz = [self makeKvoClassWithOriginalClassName:clazzName];
        object_setClass(self, clazz);
    }
    
    // add our kvo setter if this class (not superclasses) doesn't implement the setter?
    if (![self hasSelector:setterSelector]) {
        const char *types = method_getTypeEncoding(setterMethod);
        class_addMethod(clazz, setterSelector, (IMP)kvo_setter, types);
    }
    
    PGObservationInfo *info = [[PGObservationInfo alloc] initWithObserver:observer Key:keyPath block:block];
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(kPGKVOAssociatedObservers));
    if (!observers) {
        observers = [NSMutableArray array];
        objc_setAssociatedObject(self, (__bridge const void *)(kPGKVOAssociatedObservers), observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observers addObject:info];
}


- (void)PG_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
{
    //forKeyPath要做递归处理
    if ([keyPath containsString:@"."]) {
        NSArray<NSString*>* keys = [keyPath componentsSeparatedByString:@"."];
        Ivar ivar = class_getInstanceVariable(object_getClass(self),[[NSString stringWithFormat:@"_%@",keys[0]] UTF8String]);
        if (!ivar) {
            ivar = class_getInstanceVariable(object_getClass(self),[keys[0] UTF8String]);
        }
        id ob = object_getIvar(self,ivar);
        if (!ob)return;
        //递归处理
        [ob PG_removeObserver:self forKeyPath:[keyPath substringFromIndex:keys[0].length+1]];
        return;
    }
    NSMutableArray* observers = objc_getAssociatedObject(self, (__bridge const void *)(kPGKVOAssociatedObservers));
    PGObservationInfo *infoToRemove;
    for (PGObservationInfo* info in observers) {
        if (info.observer == observer && [info.key isEqual:keyPath]) {
            infoToRemove = info;
            break;
        }
    }
    [observers removeObject:infoToRemove];
}


- (Class)makeKvoClassWithOriginalClassName:(NSString *)originalClazzName
{
    NSString *kvoClazzName = [kPGKVOClassPrefix stringByAppendingString:originalClazzName];
    Class clazz = NSClassFromString(kvoClazzName);
    
    if (clazz) {
        return clazz;
    }
    
    // class doesn't exist yet, make it
    Class originalClazz = object_getClass(self);
    Class kvoClazz = objc_allocateClassPair(originalClazz, kvoClazzName.UTF8String, 0);
    
    // grab class method's signature so we can borrow it
    Method clazzMethod = class_getInstanceMethod(originalClazz, @selector(class));
    const char *types = method_getTypeEncoding(clazzMethod);
    class_addMethod(kvoClazz, @selector(class), (IMP)kvo_class, types);
    
    objc_registerClassPair(kvoClazz);
    
    return kvoClazz;
}


- (BOOL)hasSelector:(SEL)selector
{
    Class clazz = object_getClass(self);
    unsigned int methodCount = 0;
    Method* methodList = class_copyMethodList(clazz, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL thisSelector = method_getName(methodList[i]);
        if (thisSelector == selector) {
            free(methodList);
            return YES;
        }
    }
    
    free(methodList);
    return NO;
}


@end




