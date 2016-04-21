//
//  UIViewController+HZURLManager.m
//  ZHFramework
//
//  Created by xzh. on 15/8/21.
//  Copyright (c) 2015年 xzh. All rights reserved.
//

#import "UIViewController+HZURLManager.h"
#import "NSURL+HZExtend.h"
#import "NSObject+HZExtend.h"
#import "NSString+HZExtend.h"
#import "HZWebViewController.h"
#import <objc/runtime.h>

static const char kOriginURL = '\0';
static const char kQueryDic = '\1';
@interface UIViewController ()

@property(nonatomic, strong) NSString *originURL;
@property(nonatomic, strong) NSDictionary *queryDic;

@end

@implementation UIViewController (HZURLManager)
#pragma mark 创建控制器
/**
 *  根据URL创建对应的控制器
 *  目前只返回一个控制器,以后可能会扩展返回多个控制器
 */
+ (NSArray *)viewControllersWithURL:(NSString *)urlstring queryDic:(NSDictionary *)queryDic
{
    NSString *scheme = urlstring.scheme;
    NSDictionary *config = [HZURLManageConfig sharedConfig].config;
    if (!urlstring.isNoEmpty || !config.isNoEmpty) return nil;
    
    /*******************根据schema创建控制器********************/
    UIViewController *viewCtrl = nil;
    if ([scheme isEqualToString:@"http"]||[scheme isEqualToString:@"https"]) {  //schema为http
        NSString *strWebCtrl = [HZURLManageConfig sharedConfig].classOfWebViewCtrl.isNoEmpty?[HZURLManageConfig sharedConfig].classOfWebViewCtrl:@"HZWebViewController";
        Class class = NSClassFromString(strWebCtrl);
        viewCtrl = [[class alloc] initWithURL:[NSURL URLWithString:urlstring]];
    }else { //shchema为自定义
        
        id configClass = [config objectForKey:urlstring.allPath];
        
        NSString *strclass=[configClass isKindOfClass:NSString.class]?configClass:nil;
        
        NSDictionary *dictclass=[configClass isKindOfClass:NSDictionary.class]?configClass:nil;
        
        NSString *errorInfo = nil;
        Class class;
        if(strclass.isNoEmpty) {
            class = NSClassFromString(strclass);
        }else if (dictclass.isNoEmpty){
            NSString*storyBoard = dictclass[@"StoryBoard"];
            strclass = dictclass[@"Controller"];
            class = NSClassFromString(strclass);
            if (storyBoard.isNoEmpty) {
                
                @try {
                    
                    viewCtrl = [[UIStoryboard storyboardWithName:storyBoard bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:strclass];
                    
                } @catch (NSException *exception) {
                    
                    errorInfo = [NSString stringWithFormat:@"404 :) ,%@://%@ 在StoryBoard:%@ 并无 %@",urlstring.scheme,urlstring.host,storyBoard,strclass];
                } @finally {
                    
                }
                
            }
        }
        else {//无该URL
            errorInfo = [NSString stringWithFormat:@"404 :) ,%@://%@并无注册",urlstring.scheme,urlstring.host];
        }
        
        if(NULL != class && viewCtrl==nil) {
            viewCtrl = [[class alloc] init];
        }else { //无该控制器
            errorInfo=errorInfo?:[NSString stringWithFormat:@"404 :) ,%@并无注册",strclass];
        }
        
#ifdef DEBUG  // 调试状态
        viewCtrl = viewCtrl?:[self errorViewConrtollerWithInfo:errorInfo];
        
#else // 发布状态
#endif
    }
    
    if (viewCtrl) {
        NSMutableDictionary *tmpDic = [NSMutableDictionary dictionary];
        NSDictionary *urlQueryDic = urlstring.queryDic;
        if (urlQueryDic.isNoEmpty) [tmpDic addEntriesFromDictionary:urlQueryDic];
        if (queryDic.isNoEmpty) [tmpDic addEntriesFromDictionary:queryDic];
        viewCtrl.queryDic = tmpDic;
        viewCtrl.originURL = urlstring;
        
        NSDictionary *myPoperties = [self popertysInClass:viewCtrl.class];
        NSArray *myPopertiesAllKeys = myPoperties.allKeys;
        for (NSString*keyInDic in tmpDic) {
            NSObject *value = tmpDic[keyInDic];
            
            if (NSNotFound!=[myPopertiesAllKeys indexOfObject:keyInDic]) {
                
                id popertyTypeExpectedStr= myPoperties[keyInDic];
                id popertyTypeExpected = NSClassFromString(popertyTypeExpectedStr);
                
                if ([value isKindOfClass:NSClassFromString(popertyTypeExpectedStr)]) {
                    
                    [viewCtrl setValue:value forKeyPath:keyInDic];
                    
                }else{
                    NSLog(@"class = %@ poperty[%@] type=%@,BUT para isKindOfClass:%@ ",
                          NSStringFromClass(viewCtrl.class),
                          keyInDic,
                          NSStringFromClass(popertyTypeExpected),
                          NSStringFromClass([value class]));
                }
                
            }else{
                @try {
                    [viewCtrl setValue:value forKeyPath:keyInDic];
                } @catch (NSException *exception) {
                    NSLog(@"class = %@ not has poperty =%@",NSStringFromClass(viewCtrl.class),keyInDic);
                }
            }
        }
        return @[viewCtrl];
    }
    return nil;
}
+(NSDictionary *)popertysInClass:(Class)clz{
    
    NSString *className = NSStringFromClass(clz);
    
    const char *cClassName = [className UTF8String];
    
    id theClass = objc_getClass(cClassName);
    
    unsigned int outCount, i;
    
    objc_property_t *properties = class_copyPropertyList(theClass, &outCount);
    
    NSMutableDictionary *propertyDictionarys = [[NSMutableDictionary alloc] initWithCapacity:1];
    
    for (i = 0; i < outCount; i++) {
        
        
        objc_property_t property = properties[i];
        
        
        NSString *propertyNameString = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        
        // 成员类型
        NSString *attrs = @(property_getAttributes(property));
        NSUInteger dotLoc = [attrs rangeOfString:@","].location;
        NSString *code = nil;
        NSUInteger loc = 3;
        if (dotLoc == NSNotFound) { // 没有
            code = [attrs substringFromIndex:loc];
        } else {
            code = [attrs substringWithRange:NSMakeRange(loc, dotLoc - loc-1)];
        }
        NSNumber;
        [propertyDictionarys setObject:code?:[NSNull null] forKey:propertyNameString];
        
//        NSLog(@"%s code =%@ \n ", property_getName(property), code);
        
    }
    return propertyDictionarys;
}
/**
 *  创建错误控制器
 */
+ (UIViewController *)errorViewConrtollerWithInfo:(NSString *)errorInfo
{
    Class noCtrlClass = NSClassFromString(@"HZErrorViewController");
    UIViewController *viewCtrl = [[noCtrlClass alloc] init];
    [viewCtrl setValue:errorInfo forKey:@"errorInfo"];
    return viewCtrl;
}

#pragma mark - Public Method
+ (UIViewController *)viewControllerWithString:(NSString *)urlstring
{
    return [[self viewControllersWithURL:urlstring queryDic:nil] firstObject];
}

+ (UIViewController *)viewControllerWithString:(NSString *)urlstring queryDic:(NSDictionary *)query
{
    return [[self viewControllersWithURL:urlstring queryDic:query] firstObject];
}

//#pragma mark - Private
//+ (NSArray *)allPaths:(NSURL *)URL
//{
//    if (!URL.absoluteString.isNoEmpty) return nil;
//    
//    if (URL.path.isNoEmpty) {
//        NSArray *pathArray = [URL.pathComponents subarrayWithRange:NSMakeRange(1, URL.pathComponents.count-1)];
//        NSString *host = URL.host;
//        if (host.isNoEmpty) return [@[host] arrayByAddingObjectsFromArray:pathArray];
//    }else {
//        NSString *path = URL.host;
//        if (path.isNoEmpty) return @[path];
//        
//    }
//    
//    return nil;
//}

#pragma mark - Property
- (NSString *)originURL
{
    return objc_getAssociatedObject(self, &kOriginURL);
}

- (void)setOriginURL:(NSString *)originURL
{
    NSString *url = objc_getAssociatedObject(self, &kOriginURL);
    if (url != originURL) {
        [self willChangeValueForKey:@"originURL"];
        objc_setAssociatedObject(self, &kOriginURL, originURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self didChangeValueForKey:@"originURL"];
    }
}

- (NSDictionary *)queryDic
{
    return objc_getAssociatedObject(self, &kQueryDic);
}

- (void)setQueryDic:(NSDictionary *)queryDic
{
    NSDictionary *dic = objc_getAssociatedObject(self, &kQueryDic);
    if (dic != queryDic) {
        [self willChangeValueForKey:@"queryDic"];
        objc_setAssociatedObject(self, &kQueryDic, queryDic, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self didChangeValueForKey:@"queryDic"];
    }
}


@end
