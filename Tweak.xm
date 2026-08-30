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
typedef void* (*il2cpp_object_unbox_t)(void* obj);
typedef void* (*il2cpp_class_get_methods_t)(void *klass, void **iter);
typedef const char* (*il2cpp_method_get_name_t)(void *method);
typedef const char* (*il2cpp_class_get_name_t)(void *klass);
typedef const char* (*il2cpp_class_get_namespace_t)(void *klass);
typedef void* (*il2cpp_image_get_class_t)(void *image, size_t index);
typedef size_t (*il2cpp_image_get_class_count_t)(void *image);
typedef const char* (*il2cpp_image_get_name_t)(void *image);
typedef void* (*il2cpp_method_get_return_type_t)(void *method);
typedef uint32_t (*il2cpp_method_get_param_count_t)(void *method);
typedef void* (*il2cpp_method_get_param_t)(void *method, uint32_t index);
typedef const char* (*il2cpp_type_get_name_t)(void *type);
typedef bool (*il2cpp_method_is_static_t)(void *method);
typedef void* (*il2cpp_class_get_type_t)(void *klass);
typedef void* (*il2cpp_method_get_method_pointer_t)(void *method);

// v2.7: 字段相关函数
typedef void* (*il2cpp_class_get_fields_t)(void *klass, void *iter);
typedef const char* (*il2cpp_field_get_name_t)(void *field);
typedef void* (*il2cpp_field_get_type_t)(void *field);
typedef int (*il2cpp_field_get_offset_t)(void *field);
typedef bool (*il2cpp_field_is_static_t)(void *field);
typedef void (*il2cpp_field_get_value_t)(void *obj, void *field, void *value);
typedef void (*il2cpp_field_set_value_t)(void *obj, void *field, void *value);
typedef void* (*il2cpp_class_get_field_from_name_t)(void *klass, const char *name);

static il2cpp_class_get_fields_t f_class_get_fields = NULL;
static il2cpp_field_get_name_t f_field_get_name = NULL;
static il2cpp_field_get_type_t f_field_get_type = NULL;
static il2cpp_field_get_offset_t f_field_get_offset = NULL;
static il2cpp_field_is_static_t f_field_is_static = NULL;
static il2cpp_field_get_value_t f_field_get_value = NULL;
static il2cpp_field_set_value_t f_field_set_value = NULL;
static il2cpp_class_get_field_from_name_t f_class_get_field_from_name = NULL;

#pragma mark - Hook 全局变量
static float g_elapse_multiplier = 1.0f;  // ElapseTime 返回值倍数
static BOOL g_hook_installed = NO;

// 原始函数指针（v2.4 移到 hooked_ElapseTime 前面，修正调用约定）

typedef void (*SpeedHackUpdate_original_t)(void *instance);
static SpeedHackUpdate_original_t original_SpeedHackUpdate = NULL;

// 方案2：hook il2cpp_runtime_invoke 拦截 ElapseTime
static void *g_elapse_method = NULL;
typedef void* (*runtime_invoke_original_t)(void *method, void *obj, void **params, void **exc);
static runtime_invoke_original_t original_runtime_invoke = NULL;

#pragma mark - 全局变量
static void* il2cpp_image = NULL;
static void* g_set_timeScale_method = NULL;
static void* g_set_maximumDeltaTime_method = NULL;
static void* g_get_timeScale_method = NULL;
static void* g_set_fixedDeltaTime_method = NULL;
static void* g_set_captureFramerate_method = NULL;
static void* g_set_targetFrameRate_method = NULL;
static void* g_set_vSyncCount_method = NULL;
static float g_target_speed = 8.0f;
static BOOL g_speed_enabled = NO;
static BOOL g_funcs_ready = NO;
static NSString *g_diagnostic_log_path = nil;
static NSMutableString *g_diagnostic_log = nil;

// IL2CPP 函数指针
static il2cpp_domain_get_t f_domain_get = NULL;
static il2cpp_domain_get_assemblies_t f_domain_get_assemblies = NULL;
static il2cpp_assembly_get_image_t f_assembly_get_image = NULL;
static il2cpp_class_from_name_t f_class_from_name = NULL;
static il2cpp_class_get_method_from_name_t f_class_get_method_from_name = NULL;
static il2cpp_runtime_invoke_t f_runtime_invoke = NULL;
static il2cpp_value_box_t f_value_box = NULL;
static il2cpp_object_unbox_t f_object_unbox = NULL;
static il2cpp_class_get_methods_t f_class_get_methods = NULL;
static il2cpp_method_get_name_t f_method_get_name = NULL;
static il2cpp_class_get_name_t f_class_get_name = NULL;
static il2cpp_class_get_namespace_t f_class_get_namespace = NULL;
static il2cpp_image_get_class_t f_image_get_class = NULL;
static il2cpp_image_get_class_count_t f_image_get_class_count = NULL;
static il2cpp_image_get_name_t f_image_get_name = NULL;
static il2cpp_method_get_return_type_t f_method_get_return_type = NULL;
static il2cpp_method_get_param_count_t f_method_get_param_count = NULL;
static il2cpp_method_get_param_t f_method_get_param = NULL;
static il2cpp_type_get_name_t f_type_get_name = NULL;
static il2cpp_method_is_static_t f_method_is_static = NULL;
static il2cpp_class_get_type_t f_class_get_type = NULL;
static il2cpp_method_get_method_pointer_t f_method_get_method_pointer = NULL;

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
    f_class_get_methods = (il2cpp_class_get_methods_t)get_il2cpp_func("il2cpp_class_get_methods");
    f_method_get_name = (il2cpp_method_get_name_t)get_il2cpp_func("il2cpp_method_get_name");
    f_class_get_name = (il2cpp_class_get_name_t)get_il2cpp_func("il2cpp_class_get_name");
    f_class_get_namespace = (il2cpp_class_get_namespace_t)get_il2cpp_func("il2cpp_class_get_namespace");
    f_image_get_class = (il2cpp_image_get_class_t)get_il2cpp_func("il2cpp_image_get_class");
    f_image_get_class_count = (il2cpp_image_get_class_count_t)get_il2cpp_func("il2cpp_image_get_class_count");
    f_image_get_name = (il2cpp_image_get_name_t)get_il2cpp_func("il2cpp_image_get_name");
    f_method_get_return_type = (il2cpp_method_get_return_type_t)get_il2cpp_func("il2cpp_method_get_return_type");
    f_method_get_param_count = (il2cpp_method_get_param_count_t)get_il2cpp_func("il2cpp_method_get_param_count");
    f_method_get_param = (il2cpp_method_get_param_t)get_il2cpp_func("il2cpp_method_get_param");
    f_type_get_name = (il2cpp_type_get_name_t)get_il2cpp_func("il2cpp_type_get_name");
    f_method_is_static = (il2cpp_method_is_static_t)get_il2cpp_func("il2cpp_method_is_static");
    f_class_get_type = (il2cpp_class_get_type_t)get_il2cpp_func("il2cpp_class_get_type");
    f_method_get_method_pointer = (il2cpp_method_get_method_pointer_t)get_il2cpp_func("il2cpp_method_get_method_pointer");
    
    // v2.7: 字段相关函数
    f_class_get_fields = (il2cpp_class_get_fields_t)get_il2cpp_func("il2cpp_class_get_fields");
    f_field_get_name = (il2cpp_field_get_name_t)get_il2cpp_func("il2cpp_field_get_name");
    f_field_get_type = (il2cpp_field_get_type_t)get_il2cpp_func("il2cpp_field_get_type");
    f_field_get_offset = (il2cpp_field_get_offset_t)get_il2cpp_func("il2cpp_field_get_offset");
    f_field_is_static = (il2cpp_field_is_static_t)get_il2cpp_func("il2cpp_field_is_static");
    f_field_get_value = (il2cpp_field_get_value_t)get_il2cpp_func("il2cpp_field_get_value");
    f_field_set_value = (il2cpp_field_set_value_t)get_il2cpp_func("il2cpp_field_set_value");
    f_class_get_field_from_name = (il2cpp_class_get_field_from_name_t)get_il2cpp_func("il2cpp_class_get_field_from_name");
    
    NSLog(@"[SpeedUnlock] IL2CPP funcs: domain=%d, assemblies=%d, image=%d, class=%d, method=%d, invoke=%d, box=%d, unbox=%d, getMethods=%d, getMethodName=%d, getClassName=%d, getClassNS=%d, getImageClass=%d, getImageClassCount=%d, getImageName=%d",
          f_domain_get != NULL, f_domain_get_assemblies != NULL, f_assembly_get_image != NULL,
          f_class_from_name != NULL, f_class_get_method_from_name != NULL, f_runtime_invoke != NULL,
          f_value_box != NULL, f_object_unbox != NULL,
          f_class_get_methods != NULL, f_method_get_name != NULL, f_class_get_name != NULL,
          f_class_get_namespace != NULL, f_image_get_class != NULL, f_image_get_class_count != NULL,
          f_image_get_name != NULL);
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

#pragma mark - 诊断：扫描游戏程序集中的时间管理类
static void append_diagnostic_log(NSString *line) {
    if (!g_diagnostic_log) g_diagnostic_log = [NSMutableString string];
    [g_diagnostic_log appendString:line];
    [g_diagnostic_log appendString:@"\n"];
    NSLog(@"%@", line);
}

static void save_diagnostic_log(void) {
    if (!g_diagnostic_log) return;
    
    @try {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docDir = paths.firstObject;
        if (!docDir) docDir = @"/tmp";
        
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy-MM-dd_HH-mm-ss";
        NSString *filename = [NSString stringWithFormat:@"SpeedUnlock_Diagnostic_%@.txt", [fmt stringFromDate:[NSDate date]]];
        g_diagnostic_log_path = [docDir stringByAppendingPathComponent:filename];
        
        NSError *error = nil;
        [g_diagnostic_log writeToFile:g_diagnostic_log_path atomically:YES encoding:NSUTF8StringEncoding error:&error];
        
        if (error) {
            NSLog(@"[SpeedUnlock][诊断] 保存文件失败: %@", error);
        } else {
            NSLog(@"[SpeedUnlock][诊断] 诊断日志已保存: %@", g_diagnostic_log_path);
        }
    } @catch (NSException *e) {
        NSLog(@"[SpeedUnlock][诊断] 保存文件异常: %@", e);
    }
}

static void diagnose_time_classes(void) {
    if (!f_domain_get || !f_domain_get_assemblies || !f_assembly_get_image || 
        !f_image_get_class || !f_image_get_class_count || !f_class_get_name ||
        !f_class_get_methods || !f_method_get_name) {
        append_diagnostic_log(@"[SpeedUnlock][诊断] 缺少必要的IL2CPP函数，跳过诊断");
        save_diagnostic_log();
        return;
    }
    
    append_diagnostic_log(@"[SpeedUnlock][诊断] ===== 开始扫描时间管理类 =====");
    
    void *domain = f_domain_get();
    size_t asmCount = 0;
    void **assemblies = f_domain_get_assemblies(domain, &asmCount);
    
    // 关键词列表
    const char *keywords[] = {"engine", "time", "speed", "scale", "tick", "fps", "frame", "game", "play", NULL};
    
    int foundCount = 0;
    
    for (size_t i = 0; i < asmCount; i++) {
        void *image = f_assembly_get_image(assemblies[i]);
        if (!image) continue;
        
        const char *imageName = f_image_get_name ? f_image_get_name(image) : "unknown";
        
        // 只扫描游戏程序集（非 UnityEngine、非 System、非 mscorlib）
        NSString *imgName = [NSString stringWithUTF8String:imageName];
        if ([imgName containsString:@"UnityEngine"] || [imgName containsString:@"System"] ||
            [imgName containsString:@"mscorlib"] || [imgName containsString:@"netstandard"] ||
            [imgName containsString:@"Mono."] || [imgName containsString:@"I18N"]) {
            continue;
        }
        
        size_t classCount = f_image_get_class_count(image);
        
        for (size_t j = 0; j < classCount; j++) {
            void *klass = f_image_get_class(image, j);
            if (!klass) continue;
            
            const char *className = f_class_get_name(klass);
            if (!className) continue;
            
            NSString *clsName = [NSString stringWithUTF8String:className];
            
            // 检查是否包含关键词
            BOOL matched = NO;
            for (int k = 0; keywords[k]; k++) {
                if ([clsName.lowercaseString containsString:[NSString stringWithUTF8String:keywords[k]]]) {
                    matched = YES;
                    break;
                }
            }
            
            if (!matched) continue;
            
            const char *nameSpace = f_class_get_namespace ? f_class_get_namespace(klass) : "";
            
            append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][诊断] 找到匹配类: %@.%@ (程序集: %@)", 
                  [NSString stringWithUTF8String:nameSpace], clsName, imgName]);
            
            // 列出这个类的所有方法
            void *iter = NULL;
            void *method = NULL;
            int methodCount = 0;
            while ((method = f_class_get_methods(klass, &iter)) != NULL) {
                const char *methodName = f_method_get_name(method);
                if (methodName) {
                    NSString *mName = [NSString stringWithUTF8String:methodName];
                    // 只记录包含时间相关关键词的方法
                    if ([mName.lowercaseString containsString:@"time"] || 
                        [mName.lowercaseString containsString:@"speed"] ||
                        [mName.lowercaseString containsString:@"scale"] ||
                        [mName.lowercaseString containsString:@"tick"] ||
                        [mName.lowercaseString containsString:@"fps"] ||
                        [mName.lowercaseString containsString:@"delta"] ||
                        [mName.lowercaseString containsString:@"set"] ||
                        [mName.lowercaseString containsString:@"get"]) {
                        append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][诊断]   方法: %@", mName]);
                        methodCount++;
                    }
                }
            }
            
            foundCount++;
            if (foundCount >= 50) {
                append_diagnostic_log(@"[SpeedUnlock][诊断] 已找到50个匹配类，停止扫描");
                break;
            }
        }
        
        if (foundCount >= 50) break;
    }
    
    append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][诊断] ===== 扫描完成，共找到 %d 个匹配类 =====", foundCount]);
    save_diagnostic_log();
}

#pragma mark - 深度诊断：扫描关键类的所有方法签名
static void deep_diagnose_key_classes(void) {
    if (!f_domain_get || !f_domain_get_assemblies || !f_assembly_get_image || 
        !f_class_from_name || !f_class_get_methods || !f_method_get_name ||
        !f_method_get_return_type || !f_method_get_param_count || !f_type_get_name) {
        append_diagnostic_log(@"[SpeedUnlock][深度诊断] 缺少必要的IL2CPP函数，跳过深度诊断");
        save_diagnostic_log();
        return;
    }
    
    append_diagnostic_log(@"[SpeedUnlock][深度诊断] ===== 开始深度扫描关键类 =====");
    
    // 关键类列表（命名空间, 类名, 程序集关键词）
    NSArray *keyClasses = @[
        @{@"ns": @"T5Game", @"class": @"SpeedHackDetector", @"asm": @"GameBase"},
        @{@"ns": @"T5Game", @"class": @"SpeedHackHelper", @"asm": @"GameBase"},
        @{@"ns": @"DodGame", @"class": @"BTickWatcher", @"asm": @"DodGameLib"},
        @{@"ns": @"DodGame", @"class": @"BTimerTick", @"asm": @"DodGameLib"},
        @{@"ns": @"DodGame", @"class": @"FPSBehaviour", @"asm": @"GameBase"},
    ];
    
    void *domain = f_domain_get();
    size_t asmCount = 0;
    void **assemblies = f_domain_get_assemblies(domain, &asmCount);
    
    for (NSDictionary *keyClass in keyClasses) {
        NSString *ns = keyClass[@"ns"];
        NSString *className = keyClass[@"class"];
        NSString *asmKeyword = keyClass[@"asm"];
        
        append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][深度诊断] 查找类: %@.%@", ns, className]);
        
        // 在所有程序集中查找这个类
        void *foundClass = NULL;
        NSString *foundAsm = nil;
        
        for (size_t i = 0; i < asmCount; i++) {
            void *image = f_assembly_get_image(assemblies[i]);
            if (!image) continue;
            
            const char *imageName = f_image_get_name ? f_image_get_name(image) : "unknown";
            NSString *imgName = [NSString stringWithUTF8String:imageName];
            
            if (![imgName containsString:asmKeyword]) continue;
            
            void *klass = f_class_from_name(image, [ns UTF8String], [className UTF8String]);
            if (klass) {
                foundClass = klass;
                foundAsm = imgName;
                break;
            }
        }
        
        if (!foundClass) {
            append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][深度诊断]   未找到类: %@.%@", ns, className]);
            continue;
        }
        
        append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][深度诊断]   找到类: %@.%@ (程序集: %@)", ns, className, foundAsm]);
        
        // 列出这个类的所有方法（包括签名）
        void *iter = NULL;
        void *method = NULL;
        int methodCount = 0;
        
        while ((method = f_class_get_methods(foundClass, &iter)) != NULL) {
            const char *methodName = f_method_get_name(method);
            if (!methodName) continue;
            
            NSString *mName = [NSString stringWithUTF8String:methodName];
            
            // 获取方法签名
            uint32_t paramCount = f_method_get_param_count ? f_method_get_param_count(method) : 0;
            bool isStatic = f_method_is_static ? f_method_is_static(method) : false;
            
            NSMutableString *sig = [NSMutableString stringWithFormat:@"%@ (", isStatic ? @"+" : @"-"];
            
            // 返回值类型
            if (f_method_get_return_type && f_type_get_name) {
                void *retType = f_method_get_return_type(method);
                if (retType) {
                    const char *retName = f_type_get_name(retType);
                    if (retName) {
                        [sig appendString:[NSString stringWithUTF8String:retName]];
                    }
                }
            }
            [sig appendString:@" "];
            [sig appendString:mName];
            [sig appendString:@":"];
            
            // 参数类型
            for (uint32_t p = 0; p < paramCount; p++) {
                if (f_method_get_param && f_type_get_name) {
                    void *paramType = f_method_get_param(method, p);
                    if (paramType) {
                        const char *paramName = f_type_get_name(paramType);
                        if (paramName) {
                            [sig appendString:[NSString stringWithUTF8String:paramName]];
                        }
                    }
                }
                if (p < paramCount - 1) [sig appendString:@", "];
            }
            [sig appendString:@")"];
            
            append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][深度诊断]     方法: %@", sig]);
            methodCount++;
        }
        
        append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][深度诊断]   共 %d 个方法", methodCount]);
    }
    
    append_diagnostic_log(@"[SpeedUnlock][深度诊断] ===== 深度扫描完成 =====");
    save_diagnostic_log();
}

#pragma mark - Hook 函数：修改游戏时间
// v2.4：修正 IL2CPP 调用约定，添加 MethodInfo* 参数
typedef float (*ElapseTime_original_t)(void *instance, void *method);
static ElapseTime_original_t original_ElapseTime = NULL;

static int g_elapse_call_count = 0;

static float hooked_ElapseTime(void *instance, void *method) {
    if (!original_ElapseTime) return 0;
    
    g_elapse_call_count++;
    
    @try {
        float original = original_ElapseTime(instance, method);
        float modified = original * g_elapse_multiplier;
        
        // 只在加速时记录，避免日志太多
        static int logCounter = 0;
        if (g_elapse_multiplier > 1.0f && (logCounter++ % 300) == 0) {
            NSLog(@"[SpeedUnlock][Hook] ElapseTime 调用 #%d: %.4f -> %.4f (x%.1f)", 
                  g_elapse_call_count, original, modified, g_elapse_multiplier);
        }
        
        return modified;
    } @catch (NSException *e) {
        return original_ElapseTime(instance, method);
    }
}

static void hooked_SpeedHackUpdate(void *instance) {
    // 空转，禁用加速检测
    // 不调用 original_SpeedHackUpdate(instance)
}

#pragma mark - v2.5: Hook BTimerTick 构造函数（修改计时器间隔）
// v2.6: 修正签名，构造函数是 .ctor(float interval, OnTick callback)
typedef void (*BTimerTick_ctor_original_t)(void *instance, float interval, void *onTick, void *method);
static BTimerTick_ctor_original_t original_BTimerTick_ctor = NULL;
static int g_btimer_ctor_call_count = 0;

static void hooked_BTimerTick_ctor(void *instance, float interval, void *onTick, void *method) {
    g_btimer_ctor_call_count++;
    
    // 把间隔时间除以加速倍率，让计时器更快触发
    float modifiedInterval = interval;
    if (g_elapse_multiplier > 1.0f && interval > 0) {
        modifiedInterval = interval / g_elapse_multiplier;
        
        static int logCounter = 0;
        if ((logCounter++ % 100) == 0) {
            NSLog(@"[SpeedUnlock][Hook] BTimerTick.ctor 调用 #%d: %.4f -> %.4f (x%.1f)", 
                  g_btimer_ctor_call_count, interval, modifiedInterval, g_elapse_multiplier);
        }
    }
    
    original_BTimerTick_ctor(instance, modifiedInterval, onTick, method);
}

#pragma mark - v2.8: Hook Unity Time.timeScale（Unity标准时间控制）
typedef void (*Unity_Time_set_timeScale_original_t)(float value, void *method);
static Unity_Time_set_timeScale_original_t original_unity_set_timeScale = NULL;
static int g_unity_set_timescale_call_count = 0;
static float g_unity_last_timescale = 1.0f;

static void hooked_unity_set_timeScale(float value, void *method) {
    g_unity_set_timescale_call_count++;
    g_unity_last_timescale = value;
    
    // 如果游戏设置的 timeScale 小于我们想要的倍率，就改成我们的倍率
    float modifiedValue = value;
    if (g_elapse_multiplier > 1.0f && value < g_elapse_multiplier) {
        modifiedValue = g_elapse_multiplier;
    }
    
    static int logCounter = 0;
    if ((logCounter++ % 100) == 0) {
        NSLog(@"[SpeedUnlock][Hook] Unity.Time.set_timeScale 调用 #%d: %.2f -> %.2f", 
              g_unity_set_timescale_call_count, value, modifiedValue);
    }
    
    original_unity_set_timeScale(modifiedValue, method);
}
typedef void (*FPSBehaviour_UpdateScale_original_t)(void *instance, void *method);
static FPSBehaviour_UpdateScale_original_t original_FPSBehaviour_UpdateScale = NULL;
static int g_fps_update_scale_call_count = 0;

// v2.7: timeScale 字段
static void *g_timescale_field = NULL;
static float g_timescale_original = 1.0f;

static void hooked_FPSBehaviour_UpdateScale(void *instance, void *method) {
    g_fps_update_scale_call_count++;
    
    // v2.7: 如果找到 timeScale 字段，修改它的值
    if (g_timescale_field && instance && g_elapse_multiplier > 1.0f) {
        float currentValue = 0;
        f_field_get_value(instance, g_timescale_field, &currentValue);
        
        // 只在原始值不是我们设置的值时才修改（避免重复修改）
        float targetValue = g_elapse_multiplier;
        if (currentValue != targetValue) {
            f_field_set_value(instance, g_timescale_field, &targetValue);
            
            static int logCounter = 0;
            if ((logCounter++ % 300) == 0) {
                NSLog(@"[SpeedUnlock][Hook] FPSBehaviour.UpdateScale 修改 timeScale: %.2f -> %.2f", currentValue, targetValue);
            }
        }
    }
    
    // 先调用原始方法
    original_FPSBehaviour_UpdateScale(instance, method);
}

static void* hooked_runtime_invoke(void *method, void *obj, void **params, void **exc) {
    // 拦截 ElapseTime 调用
    if (method == g_elapse_method && g_elapse_multiplier > 1.0f) {
        g_elapse_call_count++;
        
        // 调用原始方法获取返回值
        void *result = original_runtime_invoke(method, obj, params, exc);
        
        // 修改返回值（float）
        if (result && f_object_unbox) {
            float *fval = (float *)f_object_unbox(result);
            if (fval) {
                float original = *fval;
                *fval = original * g_elapse_multiplier;
                
                if (g_elapse_call_count % 300 == 0) {
                    NSLog(@"[SpeedUnlock][Hook] ElapseTime (方案2) 调用 #%d: %.4f -> %.4f", 
                          g_elapse_call_count, original, *fval);
                }
            }
        }
        
        return result;
    }
    
    return original_runtime_invoke(method, obj, params, exc);
}

// 优化版：最快路径，不匹配直接调用原始函数
static void* hooked_runtime_invoke_fast(void *method, void *obj, void **params, void **exc) {
    // 最快路径：方法不匹配，直接调用原始函数
    if (method != g_elapse_method || g_elapse_multiplier <= 1.0f) {
        return original_runtime_invoke(method, obj, params, exc);
    }
    
    // ElapseTime 调用，修改返回值
    g_elapse_call_count++;
    void *result = original_runtime_invoke(method, obj, params, exc);
    
    if (result && f_object_unbox) {
        float *fval = (float *)f_object_unbox(result);
        if (fval) {
            *fval = *fval * g_elapse_multiplier;
        }
    }
    
    return result;
}

#pragma mark - 安装 Hook
static void install_game_hooks(void) {
    if (g_hook_installed) return;
    
    append_diagnostic_log(@"[SpeedUnlock][版本] ===== SpeedUnlock v2.8 =====");
    append_diagnostic_log(@"[SpeedUnlock][Hook] ===== 开始安装游戏时间Hook =====");
    append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][Hook] il2cpp_method_get_method_pointer = %p", f_method_get_method_pointer]);
    
    if (!f_domain_get || !f_domain_get_assemblies || !f_assembly_get_image || 
        !f_class_from_name || !f_class_get_method_from_name) {
        append_diagnostic_log(@"[SpeedUnlock][Hook] 缺少必要的IL2CPP函数，跳过Hook安装");
        save_diagnostic_log();
        return;
    }
    
    void *domain = f_domain_get();
    size_t asmCount = 0;
    void **assemblies = f_domain_get_assemblies(domain, &asmCount);
    
    // 查找 BTickWatcher 类
    void *tickWatcherClass = NULL;
    for (size_t i = 0; i < asmCount; i++) {
        void *image = f_assembly_get_image(assemblies[i]);
        if (!image) continue;
        const char *imageName = f_image_get_name ? f_image_get_name(image) : "";
        if (!strstr(imageName, "DodGameLib")) continue;
        
        tickWatcherClass = f_class_from_name(image, "DodGame", "BTickWatcher");
        if (tickWatcherClass) break;
    }
    
    if (!tickWatcherClass) {
        append_diagnostic_log(@"[SpeedUnlock][Hook] 未找到 BTickWatcher 类");
        save_diagnostic_log();
        return;
    }
    
    append_diagnostic_log(@"[SpeedUnlock][Hook] 找到 BTickWatcher 类");
    
    // 查找 ElapseTime 方法
    void *elapseMethod = f_class_get_method_from_name(tickWatcherClass, "ElapseTime", 0);
    if (!elapseMethod) {
        append_diagnostic_log(@"[SpeedUnlock][Hook] 未找到 ElapseTime 方法");
        save_diagnostic_log();
        return;
    }
    
    append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][Hook] 找到 ElapseTime 方法: %p", elapseMethod]);
    
    // v2.1：直接从 MethodInfo 结构体偏移量 0 读取函数指针并 hook（零开销，不卡屏）
    append_diagnostic_log(@"[SpeedUnlock][Hook] ===== v2.1 直接Hook函数指针（偏移量0）=====");
    
    // 从偏移量 0 读取函数指针
    uintptr_t *methodPtr = (uintptr_t *)elapseMethod;
    void *elapseFuncPtr = (void *)methodPtr[0];
    
    append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][Hook] ElapseTime 函数指针(偏移0): %p", elapseFuncPtr]);
    
    if (elapseFuncPtr && ((uintptr_t)elapseFuncPtr > 0x100000000 && (uintptr_t)elapseFuncPtr < 0x200000000)) {
        MSHookFunction(elapseFuncPtr, (void *)hooked_ElapseTime, (void **)&original_ElapseTime);
        append_diagnostic_log(@"[SpeedUnlock][Hook] ElapseTime Hook 安装成功（直接hook函数指针，零开销）");
        g_hook_installed = YES;
    } else {
        append_diagnostic_log(@"[SpeedUnlock][Hook] ElapseTime 函数指针无效，Hook 未安装");
    }
    
    // v2.3：暂时禁用 SpeedHackDetector.Update Hook（可能导致服务器列表打不开）
    // 只保留 ElapseTime Hook，先确认加速效果
    append_diagnostic_log(@"[SpeedUnlock][Hook] v2.3: 已禁用 SpeedHackDetector.Update Hook（排查服务器列表问题）");
    
    // v2.6：Hook BTimerTick 构造函数（修正命名空间和参数）
    // BTimerTick 在 DodGame 命名空间，程序集 DodGameLib.dll
    // 构造函数: .ctor(float interval, OnTick callback) — 2个参数
    void *btimerClass = NULL;
    for (size_t i = 0; i < asmCount; i++) {
        void *image = f_assembly_get_image(assemblies[i]);
        if (!image) continue;
        btimerClass = f_class_from_name(image, "DodGame", "BTimerTick");
        if (btimerClass) break;
    }
    
    if (btimerClass) {
        // 尝试不同参数数量的构造函数
        void *ctorMethod = f_class_get_method_from_name(btimerClass, ".ctor", 2);
        if (!ctorMethod) ctorMethod = f_class_get_method_from_name(btimerClass, ".ctor", 3);
        if (!ctorMethod) ctorMethod = f_class_get_method_from_name(btimerClass, ".ctor", 4);
        
        if (ctorMethod) {
            uintptr_t *ctorPtr = (uintptr_t *)ctorMethod;
            void *ctorFuncPtr = (void *)ctorPtr[0];
            
            append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][Hook] BTimerTick.ctor 函数指针(偏移0): %p", ctorFuncPtr]);
            
            if (ctorFuncPtr && ((uintptr_t)ctorFuncPtr > 0x100000000 && (uintptr_t)ctorFuncPtr < 0x200000000)) {
                MSHookFunction(ctorFuncPtr, (void *)hooked_BTimerTick_ctor, (void **)&original_BTimerTick_ctor);
                append_diagnostic_log(@"[SpeedUnlock][Hook] BTimerTick.ctor Hook 安装成功");
            }
        } else {
            append_diagnostic_log(@"[SpeedUnlock][Hook] 未找到 BTimerTick.ctor 方法");
        }
    } else {
        append_diagnostic_log(@"[SpeedUnlock][Hook] 未找到 BTimerTick 类");
    }
    
    // v2.6：Hook FPSBehaviour.UpdateScale（修正命名空间）
    // FPSBehaviour 在 DodGame 命名空间，程序集 GameBase.dll
    void *fpsClass = NULL;
    for (size_t i = 0; i < asmCount; i++) {
        void *image = f_assembly_get_image(assemblies[i]);
        if (!image) continue;
        fpsClass = f_class_from_name(image, "DodGame", "FPSBehaviour");
        if (fpsClass) break;
    }
    
    if (fpsClass) {
        // v2.7: 遍历所有字段，找到 timeScale 相关字段
        append_diagnostic_log(@"[SpeedUnlock][Hook] FPSBehaviour 类字段列表:");
        if (f_class_get_fields && f_field_get_name && f_field_get_offset) {
            void *iter = NULL;
            void *field = NULL;
            int fieldIndex = 0;
            while ((field = f_class_get_fields(fpsClass, &iter)) != NULL) {
                const char *fieldName = f_field_get_name(field);
                int offset = f_field_get_offset(field);
                BOOL isStatic = f_field_is_static ? f_field_is_static(field) : NO;
                
                append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][Hook]   字段[%d]: %s (偏移: %d, %@)", 
                                      fieldIndex, fieldName, offset, isStatic ? @"静态" : @"实例"]);
                
                // 查找 timeScale 相关字段
                NSString *nameStr = [NSString stringWithUTF8String:fieldName];
                if ([nameStr.lowercaseString containsString:@"timescale"] || 
                    [nameStr.lowercaseString containsString:@"time_scale"] ||
                    [nameStr.lowercaseString isEqualToString:@"scale"] ||
                    [nameStr.lowercaseString containsString:@"speed"]) {
                    if (!isStatic) {
                        g_timescale_field = field;
                        append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][Hook]   --> 找到 timeScale 字段: %s (偏移: %d)", fieldName, offset]);
                    }
                }
                fieldIndex++;
            }
        }
        
        // 如果没找到，尝试直接按名字查找
        if (!g_timescale_field && f_class_get_field_from_name) {
            g_timescale_field = f_class_get_field_from_name(fpsClass, "timeScale");
            if (!g_timescale_field) g_timescale_field = f_class_get_field_from_name(fpsClass, "TimeScale");
            if (!g_timescale_field) g_timescale_field = f_class_get_field_from_name(fpsClass, "scale");
            if (g_timescale_field) {
                append_diagnostic_log(@"[SpeedUnlock][Hook] 通过名字找到 timeScale 字段");
            }
        }
        
        void *updateScaleMethod = f_class_get_method_from_name(fpsClass, "UpdateScale", 0);
        if (updateScaleMethod) {
            uintptr_t *updateScalePtr = (uintptr_t *)updateScaleMethod;
            void *updateScaleFuncPtr = (void *)updateScalePtr[0];
            
            append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][Hook] FPSBehaviour.UpdateScale 函数指针(偏移0): %p", updateScaleFuncPtr]);
            
            if (updateScaleFuncPtr && ((uintptr_t)updateScaleFuncPtr > 0x100000000 && (uintptr_t)updateScaleFuncPtr < 0x200000000)) {
                MSHookFunction(updateScaleFuncPtr, (void *)hooked_FPSBehaviour_UpdateScale, (void **)&original_FPSBehaviour_UpdateScale);
                append_diagnostic_log(@"[SpeedUnlock][Hook] FPSBehaviour.UpdateScale Hook 安装成功");
            }
        } else {
            append_diagnostic_log(@"[SpeedUnlock][Hook] 未找到 FPSBehaviour.UpdateScale 方法");
        }
    } else {
        append_diagnostic_log(@"[SpeedUnlock][Hook] 未找到 FPSBehaviour 类");
    }
    
    // v2.8: Hook Unity Time.timeScale（Unity标准时间控制）
    void *unityTimeClass = NULL;
    for (size_t i = 0; i < asmCount; i++) {
        void *image = f_assembly_get_image(assemblies[i]);
        if (!image) continue;
        unityTimeClass = f_class_from_name(image, "UnityEngine", "Time");
        if (unityTimeClass) break;
    }
    
    if (unityTimeClass) {
        void *setTimeScaleMethod = f_class_get_method_from_name(unityTimeClass, "set_timeScale", 1);
        if (setTimeScaleMethod) {
            uintptr_t *setTimeScalePtr = (uintptr_t *)setTimeScaleMethod;
            void *setTimeScaleFuncPtr = (void *)setTimeScalePtr[0];
            
            append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][Hook] Unity.Time.set_timeScale 函数指针(偏移0): %p", setTimeScaleFuncPtr]);
            
            if (setTimeScaleFuncPtr && ((uintptr_t)setTimeScaleFuncPtr > 0x100000000 && (uintptr_t)setTimeScaleFuncPtr < 0x200000000)) {
                MSHookFunction(setTimeScaleFuncPtr, (void *)hooked_unity_set_timeScale, (void **)&original_unity_set_timeScale);
                append_diagnostic_log(@"[SpeedUnlock][Hook] Unity.Time.set_timeScale Hook 安装成功");
            }
        } else {
            append_diagnostic_log(@"[SpeedUnlock][Hook] 未找到 Unity.Time.set_timeScale 方法");
        }
    } else {
        append_diagnostic_log(@"[SpeedUnlock][Hook] 未找到 UnityEngine.Time 类");
    }
    
    append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][Hook] ===== Hook安装完成，状态: %@ =====", g_hook_installed ? @"成功" : @"失败"]);
    save_diagnostic_log();
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
    
    // set_fixedDeltaTime
    g_set_fixedDeltaTime_method = f_class_get_method_from_name(timeClass, "set_fixedDeltaTime", 1);
    if (!g_set_fixedDeltaTime_method) {
        g_set_fixedDeltaTime_method = f_class_get_method_from_name(timeClass, "fixedDeltaTime", 1);
    }
    
    // set_captureFramerate
    g_set_captureFramerate_method = f_class_get_method_from_name(timeClass, "set_captureFramerate", 1);
    
    // Application.targetFrameRate
    void *appClass = find_unity_class("Application");
    if (appClass) {
        g_set_targetFrameRate_method = f_class_get_method_from_name(appClass, "set_targetFrameRate", 1);
    }
    
    // QualitySettings.vSyncCount
    void *qualityClass = find_unity_class("QualitySettings");
    if (qualityClass) {
        g_set_vSyncCount_method = f_class_get_method_from_name(qualityClass, "set_vSyncCount", 1);
    }
    
    NSLog(@"[SpeedUnlock] Methods: setTS=%p, setMaxDT=%p, getTS=%p, setFixedDT=%p, setCapFR=%p, setTargetFR=%p, setVSync=%p",
          g_set_timeScale_method, g_set_maximumDeltaTime_method, g_get_timeScale_method,
          g_set_fixedDeltaTime_method, g_set_captureFramerate_method,
          g_set_targetFrameRate_method, g_set_vSyncCount_method);
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

static void set_fixed_delta_time(float value) {
    if (!g_set_fixedDeltaTime_method || !f_runtime_invoke) return;
    
    @try {
        void *params[1] = {&value};
        void *exc = NULL;
        f_runtime_invoke(g_set_fixedDeltaTime_method, NULL, params, &exc);
    } @catch (NSException *e) {
        NSLog(@"[SpeedUnlock] set_fixed_delta_time exception: %@", e);
    }
}

static void set_capture_framerate(int value) {
    if (!g_set_captureFramerate_method || !f_runtime_invoke) return;
    
    @try {
        void *params[1] = {&value};
        void *exc = NULL;
        f_runtime_invoke(g_set_captureFramerate_method, NULL, params, &exc);
    } @catch (NSException *e) {
        NSLog(@"[SpeedUnlock] set_capture_framerate exception: %@", e);
    }
}

static void set_target_framerate(int value) {
    if (!g_set_targetFrameRate_method || !f_runtime_invoke) return;
    
    @try {
        void *params[1] = {&value};
        void *exc = NULL;
        f_runtime_invoke(g_set_targetFrameRate_method, NULL, params, &exc);
    } @catch (NSException *e) {
        NSLog(@"[SpeedUnlock] set_target_framerate exception: %@", e);
    }
}

static void set_vsync_count(int value) {
    if (!g_set_vSyncCount_method || !f_runtime_invoke) return;
    
    @try {
        void *params[1] = {&value};
        void *exc = NULL;
        f_runtime_invoke(g_set_vSyncCount_method, NULL, params, &exc);
    } @catch (NSException *e) {
        NSLog(@"[SpeedUnlock] set_vsync_count exception: %@", e);
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
    
    // 设置 fixedDeltaTime 为很小的值，让物理/逻辑更新更频繁
    // 原始值通常是 0.02（50Hz），调成 0.002（500Hz），相当于 10 倍物理更新
    set_fixed_delta_time(0.002f);
    
    // 关闭 captureFramerate（设为 0 表示不限制）
    set_capture_framerate(0);
    
    // 提高目标帧率
    set_target_framerate(120);
    
    // 关闭垂直同步
    set_vsync_count(0);
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
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"SpeedUnlock 加速破解" 
            message:[NSString stringWithFormat:@"Unity: %.0fx %@\n游戏时间: %.1fx %@", 
                g_target_speed, g_speed_enabled ? @"已开启" : @"已关闭",
                g_elapse_multiplier, g_elapse_multiplier > 1.0 ? @"已开启" : @"已关闭"]
            preferredStyle:UIAlertControllerStyleActionSheet];
        
        // 游戏时间加速（ElapseTime Hook）— 这是真正突破4倍限制的方法
        [alert addAction:[UIAlertAction actionWithTitle:@"═══ 游戏时间加速（推荐）═══" style:UIAlertActionStyleDefault handler:nil]];
        
        NSArray *elapseSpeeds = @[@1.0, @2.0, @4.0, @6.0, @8.0, @12.0, @16.0];
        for (NSNumber *s in elapseSpeeds) {
            NSString *title = [NSString stringWithFormat:@"游戏时间 %.1fx", s.floatValue];
            [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                g_elapse_multiplier = s.floatValue;
                NSLog(@"[SpeedUnlock] ElapseTime multiplier set to %.1fx", g_elapse_multiplier);
            }]];
        }
        
        // Unity timeScale 加速
        [alert addAction:[UIAlertAction actionWithTitle:@"═══ Unity timeScale（备用）═══" style:UIAlertActionStyleDefault handler:nil]];
        
        NSArray *speeds = @[@1.0, @2.0, @4.0, @8.0, @16.0, @32.0];
        for (NSNumber *s in speeds) {
            NSString *title = [NSString stringWithFormat:@"Unity %.0fx", s.floatValue];
            [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                g_target_speed = s.floatValue;
                g_speed_enabled = YES;
                NSLog(@"[SpeedUnlock] Unity speed set to %.0fx", g_target_speed);
            }]];
        }
        
        [alert addAction:[UIAlertAction actionWithTitle:@"全部关闭" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            g_speed_enabled = NO;
            g_elapse_multiplier = 1.0f;
            set_time_scale(1.0f);
            NSLog(@"[SpeedUnlock] All speed disabled");
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"导出诊断日志" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            @try {
                // v2.4：导出前追加 ElapseTime 调用次数
                append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][运行时] ElapseTime 累计调用次数: %d", g_elapse_call_count]);
                append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][运行时] BTimerTick.ctor 累计调用次数: %d", g_btimer_ctor_call_count]);
                append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][运行时] FPSBehaviour.UpdateScale 累计调用次数: %d", g_fps_update_scale_call_count]);
                append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][运行时] Unity.Time.set_timeScale 累计调用次数: %d", g_unity_set_timescale_call_count]);
                append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][运行时] Unity.Time 最后设置的 timeScale: %.2f", g_unity_last_timescale]);
                append_diagnostic_log([NSString stringWithFormat:@"[SpeedUnlock][运行时] 当前加速倍率: %.1f", g_elapse_multiplier]);
                save_diagnostic_log();
                
                if (!g_diagnostic_log_path || ![[NSFileManager defaultManager] fileExistsAtPath:g_diagnostic_log_path]) {
                    UIAlertController *tip = [UIAlertController alertControllerWithTitle:@"提示" message:@"诊断日志还没生成，请等10秒后再试" preferredStyle:UIAlertControllerStyleAlert];
                    [tip addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                    UIViewController *r = [UIApplication sharedApplication].keyWindow.rootViewController;
                    while (r.presentedViewController) r = r.presentedViewController;
                    [r presentViewController:tip animated:YES completion:nil];
                    return;
                }
                
                NSURL *fileURL = [NSURL fileURLWithPath:g_diagnostic_log_path];
                UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
                
                if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                    activityVC.popoverPresentationController.sourceView = self.button;
                    activityVC.popoverPresentationController.sourceRect = self.button.bounds;
                }
                
                UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
                while (root.presentedViewController) root = root.presentedViewController;
                [root presentViewController:activityVC animated:YES completion:nil];
            } @catch (NSException *e) {
                NSLog(@"[SpeedUnlock] 导出诊断日志异常: %@", e);
            }
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
                
                // 诊断：扫描游戏程序集中的时间管理类
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                    diagnose_time_classes();
                    // 深度诊断：扫描关键类的所有方法签名
                    deep_diagnose_key_classes();
                    // 安装游戏时间Hook
                    install_game_hooks();
                });
                
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
