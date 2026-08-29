#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <substrate.h>

#pragma mark - IL2CPP 函数指针类型
typedef void* (*il2cpp_domain_get_t)(void);
typedef void** (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef void* (*il2cpp_assembly_get_image_t)(void* assembly);
typedef void* (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
typedef void* (*il2cpp_class_get_method_from_name_t)(void* klass, const char* name, int argsCount);
typedef void* (*il2cpp_runtime_invoke_t)(void* method, void* obj, void** params, void** exc);
typedef void* (*il2cpp_value_box_t)(void* klass, void* value);
typedef void* (*il2cpp_class_get_field_from_name_t)(void* klass, const char* name);
typedef void* (*il2cpp_field_get_value_t)(void* obj, void* field);
typedef void* (*il2cpp_object_unbox_t)(void* obj);

#pragma mark - 全局变量
static void* il2cpp_image = NULL;
static void* g_set_timeScale_method = NULL;
static void* g_set_maximumDeltaTime_method = NULL;
static void* g_get_timeScale_method = NULL;
static float g_target_speed = 8.0f;
static BOOL g_speed_enabled = NO;
static BOOL g_funcs_ready = NO;

// IL2CPP 函数指针
static il2cpp_domain_get_t f_domain_get = NULL;
static il2cpp_domain_get_assemblies_t f_domain_get_assemblies = NULL;
static il2cpp_assembly_get_image_t f_assembly_get_image = NULL;
static il2cpp_class_from_name_t f_class_from_name = NULL;
static il2cpp_class_get_method_from_name_t f_class_get_method_from_name = NULL;
static il2cpp_runtime_invoke_t f_runtime_invoke = NULL;
static il2cpp_value_box_t f_value_box = NULL;
static il2cpp_object_unbox_t f_object_unbox = NULL;

#pragma mark - 工具函数
static void* get_il2cpp_func(const char *name) {
    return dlsym(RTLD_DEFAULT, name);
}

static void init_il2cpp_funcs(void) {
    if (g_funcs_ready) return;
    g_funcs_ready = YES;
    
    f_domain_get = (il2cpp_domain_get_t)get_il2cpp_func("il2cpp_domain_get");
    f_domain_get_assemblies = (il2cpp_domain_get_assemblies_t)get_il2cpp_func("il2cpp_domain_get_assemblies");
    f_assembly_get_image = (il2cpp_assembly_get_image_t)get_il2cpp_func("il2cpp_assembly_get_image");
    f_class_from_name = (il2cpp_class_from_name_t)get_il2cpp_func("il2cpp_class_from_name");
    f_class_get_method_from_name = (il2cpp_class_get_method_from_name_t)get_il2cpp_func("il2cpp_class_get_method_from_name");
    f_runtime_invoke = (il2cpp_runtime_invoke_t)get_il2cpp_func("il2cpp_runtime_invoke");
    f_value_box = (il2cpp_value_box_t)get_il2cpp_func("il2cpp_value_box");
    f_object_unbox = (il2cpp_object_unbox_t)get_il2cpp_func("il2cpp_object_unbox");
    
    NSLog(@"[SpeedUnlock] IL2CPP funcs: domain=%d, assemblies=%d, image=%d, class=%d, method=%d, invoke=%d, box=%d, unbox=%d",
          f_domain_get != NULL, f_domain_get_assemblies != NULL, f_assembly_get_image != NULL,
          f_class_from_name != NULL, f_class_get_method_from_name != NULL, f_runtime_invoke != NULL,
          f_value_box != NULL, f_object_unbox != NULL);
}

static void* find_unity_class(const char *name) {
    if (!il2cpp_image || !f_class_from_name) return NULL;
    
    const char *namespaces[] = {"UnityEngine", "", "UnityEngine.CoreModule", NULL};
    for (int i = 0; namespaces[i]; i++) {
        void *klass = f_class_from_name(il2cpp_image, namespaces[i], name);
        if (klass) return klass;
    }
    return NULL;
}

static void find_il2cpp_image(void) {
    if (!f_domain_get || !f_domain_get_assemblies || !f_assembly_get_image || !f_class_from_name) return;
    
    void *domain = f_domain_get();
    size_t asm_count = 0;
    void **assemblies = f_domain_get_assemblies(domain, &asm_count);
    
    for (size_t i = 0; i < asm_count; i++) {
        void *image = f_assembly_get_image(assemblies[i]);
        if (!image) continue;
        
        void *timeClass = f_class_from_name(image, "UnityEngine", "Time");
        if (timeClass) {
            il2cpp_image = image;
            NSLog(@"[SpeedUnlock] Found Unity image at assembly %zu", i);
            break;
        }
    }
}

static void find_time_methods(void) {
    if (!il2cpp_image || !f_class_get_method_from_name) return;
    
    void *timeClass = find_unity_class("Time");
    if (!timeClass) {
        NSLog(@"[SpeedUnlock] Time class not found");
        return;
    }
    
    // 尝试 set_timeScale 和 timeScale（setter）
    g_set_timeScale_method = f_class_get_method_from_name(timeClass, "set_timeScale", 1);
    if (!g_set_timeScale_method) {
        g_set_timeScale_method = f_class_get_method_from_name(timeClass, "timeScale", 1);
    }
    
    // 尝试 set_maximumDeltaTime
    g_set_maximumDeltaTime_method = f_class_get_method_from_name(timeClass, "set_maximumDeltaTime", 1);
    if (!g_set_maximumDeltaTime_method) {
        g_set_maximumDeltaTime_method = f_class_get_method_from_name(timeClass, "maximumDeltaTime", 1);
    }
    
    // get_timeScale
    g_get_timeScale_method = f_class_get_method_from_name(timeClass, "get_timeScale", 0);
    if (!g_get_timeScale_method) {
        g_get_timeScale_method = f_class_get_method_from_name(timeClass, "timeScale", 0);
    }
    
    NSLog(@"[SpeedUnlock] Methods: set_timeScale=%p, set_maxDelta=%p, get_timeScale=%p",
          g_set_timeScale_method, g_set_maximumDeltaTime_method, g_get_timeScale_method);
}

#pragma mark - 设置 timeScale（直接传 float 指针，不用装箱）
static void set_time_scale(float value) {
    if (!g_set_timeScale_method || !f_runtime_invoke) return;
    
    @try {
        // IL2CPP 值类型参数直接传指针，不需要 il2cpp_value_box
        void *params[1] = {&value};
        void *exc = NULL;
        f_runtime_invoke(g_set_timeScale_method, NULL, params, &exc);
        if (exc) {
            NSLog(@"[SpeedUnlock] set_time_scale exception: %f", value);
        }
    } @catch (NSException *e) {
        NSLog(@"[SpeedUnlock] set_time_scale exception: %@", e);
    }
}

static void set_maximum_delta_time(float value) {
    if (!g_set_maximumDeltaTime_method || !f_runtime_invoke) return;
    
    @try {
        void *params[1] = {&value};
        void *exc = NULL;
        f_runtime_invoke(g_set_maximumDeltaTime_method, NULL, params, &exc);
    } @catch (NSException *e) {
        NSLog(@"[SpeedUnlock] set_maximum_delta_time exception: %@", e);
    }
}

static float get_current_time_scale(void) {
    if (!g_get_timeScale_method || !f_runtime_invoke || !f_object_unbox) return -1;
    
    @try {
        void *exc = NULL;
        void *result = f_runtime_invoke(g_get_timeScale_method, NULL, NULL, &exc);
        if (result && !exc) {
            float *fval = (float *)f_object_unbox(result);
            return fval ? *fval : -1;
        }
    } @catch (NSException *e) {
        NSLog(@"[SpeedUnlock] get_current_time_scale exception: %@", e);
    }
    return -1;
}

#pragma mark - 加速定时器
static void speed_timer_callback(void) {
    if (!g_speed_enabled) return;
    
    // 强制设置 timeScale，防止游戏代码重置
    set_time_scale(g_target_speed);
    
    // 设置 maximumDeltaTime 为很大的值，确保高倍加速不被限制
    set_maximum_delta_time(100.0f);
}

#pragma mark - 悬浮按钮
@interface SpeedUnlockButton : UIView
@property (nonatomic, strong) UIButton *button;
@end

@implementation SpeedUnlockButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        
        self.button = [UIButton buttonWithType:UIButtonTypeCustom];
        self.button.frame = CGRectMake(0, 0, 60, 60);
        self.button.backgroundColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.2 alpha:0.9];
        self.button.layer.cornerRadius = 30;
        self.button.clipsToBounds = YES;
        [self.button setTitle:@"速" forState:UIControlStateNormal];
        self.button.titleLabel.font = [UIFont boldSystemFontOfSize:20];
        [self.button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.button addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.button];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.button addGestureRecognizer:pan];
    }
    return self;
}

- (void)buttonTapped {
    @try {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"SpeedUnlock 加速破解" message:[NSString stringWithFormat:@"当前: %.0fx  %@", g_target_speed, g_speed_enabled ? @"已开启" : @"已关闭"] preferredStyle:UIAlertControllerStyleActionSheet];
        
        NSArray *speeds = @[@1.0, @2.0, @4.0, @8.0, @16.0, @32.0];
        for (NSNumber *s in speeds) {
            NSString *title = [NSString stringWithFormat:@"%.0fx 加速", s.floatValue];
            [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                g_target_speed = s.floatValue;
                g_speed_enabled = YES;
                NSLog(@"[SpeedUnlock] Set speed to %.0fx", g_target_speed);
            }]];
        }
        
        [alert addAction:[UIAlertAction actionWithTitle:@"关闭加速" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            g_speed_enabled = NO;
            set_time_scale(1.0f);
            NSLog(@"[SpeedUnlock] Speed disabled");
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = self.button;
            alert.popoverPresentationController.sourceRect = self.button.bounds;
        }
        
        UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (root.presentedViewController) root = root.presentedViewController;
        [root presentViewController:alert animated:YES completion:nil];
    } @catch (NSException *e) {
        NSLog(@"[SpeedUnlock] buttonTapped exception: %@", e);
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.superview];
    CGPoint newCenter = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    newCenter.x = MAX(30, MIN(screenSize.width - 30, newCenter.x));
    newCenter.y = MAX(30, MIN(screenSize.height - 30, newCenter.y));
    self.center = newCenter;
    [pan setTranslation:CGPointZero inView:self.superview];
}

@end

#pragma mark - 初始化
static SpeedUnlockButton *g_floating_button = nil;

__attribute__((constructor))
static void initialize() {
    @autoreleasepool {
        // 延迟初始化，等游戏启动完成
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try {
                NSLog(@"[SpeedUnlock] Initializing...");
                
                init_il2cpp_funcs();
                find_il2cpp_image();
                find_time_methods();
                
                NSLog(@"[SpeedUnlock] Init results: image=%p, set_timeScale=%p, set_maxDelta=%p, get_timeScale=%p",
                      il2cpp_image, g_set_timeScale_method, g_set_maximumDeltaTime_method, g_get_timeScale_method);
                
                // 测试设置 timeScale
                if (g_set_timeScale_method && f_runtime_invoke) {
                    NSLog(@"[SpeedUnlock] Testing set_timeScale(8.0)...");
                    set_time_scale(8.0f);
                    
                    // 验证是否设置成功
                    if (g_get_timeScale_method && f_object_unbox) {
                        void *exc = NULL;
                        void *result = f_runtime_invoke(g_get_timeScale_method, NULL, NULL, &exc);
                        if (result && !exc) {
                            float *fval = (float *)f_object_unbox(result);
                            NSLog(@"[SpeedUnlock] Verify: current timeScale = %.3f", fval ? *fval : -1);
                        }
                    }
                    
                    // 恢复 1 倍
                    set_time_scale(1.0f);
                }
                
                // 总是显示悬浮按钮
                CGSize screenSize = [UIScreen mainScreen].bounds.size;
                g_floating_button = [[SpeedUnlockButton alloc] initWithFrame:CGRectMake(screenSize.width - 80, 300, 60, 60)];
                UIWindow *keyWin = [UIApplication sharedApplication].keyWindow;
                if (keyWin) {
                    [keyWin addSubview:g_floating_button];
                    NSLog(@"[SpeedUnlock] Floating button shown");
                } else {
                    NSLog(@"[SpeedUnlock] keyWindow is nil, retry in 1s");
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        UIWindow *win = [UIApplication sharedApplication].keyWindow;
                        if (win && g_floating_button) [win addSubview:g_floating_button];
                    });
                }
                
                // 启动加速定时器（每 0.1 秒强制设置一次）
                if (g_set_timeScale_method) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        __block void (^timerBlock)(void);
                        timerBlock = ^{
                            @try {
                                speed_timer_callback();
                            } @catch (NSException *e) {
                                NSLog(@"[SpeedUnlock] timer exception: %@", e);
                            }
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), timerBlock);
                        };
                        timerBlock();
                    });
                    NSLog(@"[SpeedUnlock] Speed timer started");
                }
            } @catch (NSException *e) {
                NSLog(@"[SpeedUnlock] init exception: %@", e);
            }
        });
    }
}
