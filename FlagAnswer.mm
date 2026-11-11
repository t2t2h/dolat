// FlagAnswer.mm
// إذا أحد نزل علم (إيموجي) بالدردشة، يكتب تلقائياً داخل الكيبورد المفتوح:
//   الخيار 1: اسم الدولة     الخيار 2: اسم العاصمة
// مدموج داخل منيو AflatoonSuite (قسم "اجوبة الأعلام") — بدون زر عائم منفصل.
//
// ما يحتاج fishhook، يستخدم method swizzling العادي (يشتغل بدون جيلبريك).

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ---------- إعدادات ----------
static const BOOL         kOnlyFlag  = YES;  // YES = الرسالة لازم تكون علم لحاله. NO = أي رسالة فيها علم
static const BOOL         kAutoSend  = NO;   // YES = بعد الكتابة يضغط Enter (إرسال)
static const NSTimeInterval kTypeDelay = 0.3;
static const NSTimeInterval kDedupe    = 2.0; // نفس العلم ما ينكتب مرتين خلال هالمدة

static int gMode = 0;   // 0 = OFF, 1 = اسم الدولة, 2 = العاصمة
extern "C" void FA_SetMode(int m) { gMode = (m < 0 || m > 2) ? 0 : m; }
extern "C" int  FA_GetMode(void) { return gMode; }

// ---------- البيانات: الكود|الاسم|العاصمة ----------
static NSDictionary<NSString *, NSArray<NSString *> *> *faTable() {
    static NSDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *raw =
        @"AF|أفغانستان|كابول\nAL|ألبانيا|تيرانا\nDZ|الجزائر|الجزائر\nAD|أندورا|أندورا لا فيلا\nAO|أنغولا|لواندا\n"
        @"AG|أنتيغوا وبربودا|سانت جونز\nAR|الأرجنتين|بوينس آيرس\nAM|أرمينيا|يريفان\nAU|أستراليا|كانبرا\nAT|النمسا|فيينا\n"
        @"AZ|أذربيجان|باكو\nBS|الباهاما|ناسو\nBH|البحرين|المنامة\nBD|بنغلاديش|دكا\nBB|بربادوس|بريدجتاون\n"
        @"BY|بيلاروسيا|مينسك\nBE|بلجيكا|بروكسل\nBZ|بليز|بلموبان\nBJ|بنين|بورتو نوفو\nBT|بوتان|تيمفو\n"
        @"BO|بوليفيا|سوكري\nBA|البوسنة والهرسك|سراييفو\nBW|بوتسوانا|غابورون\nBR|البرازيل|برازيليا\nBN|بروناي|بندر سيري بيغاوان\n"
        @"BG|بلغاريا|صوفيا\nBF|بوركينا فاسو|واغادوغو\nBI|بوروندي|جيتيغا\nKH|كمبوديا|بنوم بنه\nCM|الكاميرون|ياوندي\n"
        @"CA|كندا|أوتاوا\nCV|الرأس الأخضر|برايا\nCF|أفريقيا الوسطى|بانغي\nTD|تشاد|إنجامينا\nCL|تشيلي|سانتياغو\n"
        @"CN|الصين|بكين\nCO|كولومبيا|بوغوتا\nKM|جزر القمر|موروني\nCG|الكونغو|برازافيل\nCD|الكونغو الديمقراطية|كينشاسا\n"
        @"CR|كوستاريكا|سان خوسيه\nCI|ساحل العاج|ياموسوكرو\nHR|كرواتيا|زغرب\nCU|كوبا|هافانا\nCY|قبرص|نيقوسيا\n"
        @"CZ|التشيك|براغ\nDK|الدنمارك|كوبنهاغن\nDJ|جيبوتي|جيبوتي\nDM|دومينيكا|روسو\nDO|الدومينيكان|سانتو دومينغو\n"
        @"EC|الإكوادور|كيتو\nEG|مصر|القاهرة\nSV|السلفادور|سان سلفادور\nGQ|غينيا الاستوائية|مالابو\nER|إريتريا|أسمرة\n"
        @"EE|إستونيا|تالين\nSZ|إسواتيني|مبابان\nET|إثيوبيا|أديس أبابا\nFJ|فيجي|سوفا\nFI|فنلندا|هلسنكي\n"
        @"FR|فرنسا|باريس\nGA|الغابون|ليبرفيل\nGM|غامبيا|بانجول\nGE|جورجيا|تبليسي\nDE|ألمانيا|برلين\n"
        @"GH|غانا|أكرا\nGR|اليونان|أثينا\nGD|غرينادا|سانت جورجز\nGT|غواتيمالا|غواتيمالا\nGN|غينيا|كوناكري\n"
        @"GW|غينيا بيساو|بيساو\nGY|غيانا|جورج تاون\nHT|هايتي|بورت أو برنس\nHN|هندوراس|تيغوسيغالبا\nHU|المجر|بودابست\n"
        @"IS|آيسلندا|ريكيافيك\nIN|الهند|نيودلهي\nID|إندونيسيا|جاكرتا\nIR|إيران|طهران\nIQ|العراق|بغداد\n"
        @"IE|أيرلندا|دبلن\nIT|إيطاليا|روما\nJM|جامايكا|كينغستون\nJP|اليابان|طوكيو\nJO|الأردن|عمّان\n"
        @"KZ|كازاخستان|أستانا\nKE|كينيا|نيروبي\nKI|كيريباتي|تاراوا\nKW|الكويت|الكويت\nKG|قيرغيزستان|بيشكيك\n"
        @"LA|لاوس|فيينتيان\nLV|لاتفيا|ريغا\nLB|لبنان|بيروت\nLS|ليسوتو|ماسيرو\nLR|ليبيريا|مونروفيا\n"
        @"LY|ليبيا|طرابلس\nLI|ليختنشتاين|فادوز\nLT|ليتوانيا|فيلنيوس\nLU|لوكسمبورغ|لوكسمبورغ\nMG|مدغشقر|أنتاناناريفو\n"
        @"MW|مالاوي|ليلونغوي\nMY|ماليزيا|كوالالمبور\nMV|المالديف|ماليه\nML|مالي|باماكو\nMT|مالطا|فاليتا\n"
        @"MH|جزر مارشال|ماجورو\nMR|موريتانيا|نواكشوط\nMU|موريشيوس|بورت لويس\nMX|المكسيك|مكسيكو سيتي\nFM|ميكرونيزيا|باليكير\n"
        @"MD|مولدوفا|كيشيناو\nMC|موناكو|موناكو\nMN|منغوليا|أولان باتور\nME|الجبل الأسود|بودغوريتسا\nMA|المغرب|الرباط\n"
        @"MZ|موزمبيق|مابوتو\nMM|ميانمار|نايبيداو\nNA|ناميبيا|ويندهوك\nNR|ناورو|يارين\nNP|نيبال|كاتماندو\n"
        @"NL|هولندا|أمستردام\nNZ|نيوزيلندا|ويلنغتون\nNI|نيكاراغوا|ماناغوا\nNE|النيجر|نيامي\nNG|نيجيريا|أبوجا\n"
        @"KP|كوريا الشمالية|بيونغ يانغ\nMK|مقدونيا الشمالية|سكوبيه\nNO|النرويج|أوسلو\nOM|عُمان|مسقط\nPK|باكستان|إسلام آباد\n"
        @"PW|بالاو|نغيرولمود\nPS|فلسطين|القدس\nPA|بنما|بنما\nPG|بابوا غينيا الجديدة|بورت مورسبي\nPY|باراغواي|أسونسيون\n"
        @"PE|بيرو|ليما\nPH|الفلبين|مانيلا\nPL|بولندا|وارسو\nPT|البرتغال|لشبونة\nQA|قطر|الدوحة\n"
        @"RO|رومانيا|بوخارست\nRU|روسيا|موسكو\nRW|رواندا|كيغالي\nKN|سانت كيتس ونيفيس|باسيتير\nLC|سانت لوسيا|كاستريس\n"
        @"VC|سانت فنسنت والغرينادين|كينغستاون\nWS|ساموا|أبيا\nSM|سان مارينو|سان مارينو\nST|ساو تومي وبرينسيبي|ساو تومي\nSA|السعودية|الرياض\n"
        @"SN|السنغال|داكار\nRS|صربيا|بلغراد\nSC|سيشل|فيكتوريا\nSL|سيراليون|فريتاون\nSG|سنغافورة|سنغافورة\n"
        @"SK|سلوفاكيا|براتيسلافا\nSI|سلوفينيا|ليوبليانا\nSB|جزر سليمان|هونيارا\nSO|الصومال|مقديشو\nZA|جنوب أفريقيا|بريتوريا\n"
        @"KR|كوريا الجنوبية|سيول\nSS|جنوب السودان|جوبا\nES|إسبانيا|مدريد\nLK|سريلانكا|كولومبو\nSD|السودان|الخرطوم\n"
        @"SR|سورينام|باراماريبو\nSE|السويد|ستوكهولم\nCH|سويسرا|برن\nSY|سوريا|دمشق\nTW|تايوان|تايبيه\n"
        @"TJ|طاجيكستان|دوشانبي\nTZ|تنزانيا|دودوما\nTH|تايلاند|بانكوك\nTL|تيمور الشرقية|ديلي\nTG|توغو|لومي\n"
        @"TO|تونغا|نوكو ألوفا\nTT|ترينيداد وتوباغو|بورت أوف سبين\nTN|تونس|تونس\nTR|تركيا|أنقرة\nTM|تركمانستان|عشق آباد\n"
        @"TV|توفالو|فونافوتي\nUG|أوغندا|كمبالا\nUA|أوكرانيا|كييف\nAE|الإمارات|أبوظبي\nGB|بريطانيا|لندن\n"
        @"US|أمريكا|واشنطن\nUY|الأوروغواي|مونتيفيديو\nUZ|أوزبكستان|طشقند\nVU|فانواتو|بورت فيلا\nVA|الفاتيكان|الفاتيكان\n"
        @"VE|فنزويلا|كاراكاس\nVN|فيتنام|هانوي\nYE|اليمن|صنعاء\nZM|زامبيا|لوساكا\nZW|زيمبابوي|هراري\nXK|كوسوفو|بريشتينا";
        NSMutableDictionary *m = [NSMutableDictionary dictionary];
        for (NSString *line in [raw componentsSeparatedByString:@"\n"]) {
            NSArray *p = [line componentsSeparatedByString:@"|"];
            if (p.count == 3) m[p[0]] = @[p[1], p[2]];
        }
        d = m;
    });
    return d;
}

// ---------- استخراج كود الدولة من إيموجي العلم ----------
static NSString *faCode(NSString *s) {
    NSString *t = [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (t.length < 4 || (kOnlyFlag && t.length != 4)) return nil;
    for (NSUInteger i = 0; i + 3 < t.length; i++) {
        unichar a = [t characterAtIndex:i],     b = [t characterAtIndex:i + 1];
        unichar c = [t characterAtIndex:i + 2], d = [t characterAtIndex:i + 3];
        if (a == 0xD83C && c == 0xD83C && b >= 0xDDE6 && b <= 0xDDFF && d >= 0xDDE6 && d <= 0xDDFF)
            return [NSString stringWithFormat:@"%c%c", 'A' + (b - 0xDDE6), 'A' + (d - 0xDDE6)];
    }
    return nil;
}

// ---------- ايجاد الكيبورد المفتوح والكتابة فيه ----------
static __weak id gFirst;
@interface UIResponder (FlagAnswer) - (void)fa_grab; @end
@implementation UIResponder (FlagAnswer) - (void)fa_grab { gFirst = self; } @end

static void faType(NSString *text) {
    gFirst = nil;
    [UIApplication.sharedApplication sendAction:@selector(fa_grab) to:nil from:nil forEvent:nil];
    id r = gFirst;
    if (r && [r conformsToProtocol:@protocol(UIKeyInput)]) {
        [(id<UIKeyInput>)r insertText:text];
        if (kAutoSend) [(id<UIKeyInput>)r insertText:@"\n"];
    }
}

static NSString *gLastCode; static CFAbsoluteTime gLastTime;

static void faCheck(NSString *s) {
    if (!gMode || ![s isKindOfClass:NSString.class]) return;
    NSString *code = faCode(s);
    if (!code) return;
    NSArray *e = faTable()[code];
    if (!e) return;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if ([code isEqualToString:gLastCode] && now - gLastTime < kDedupe) return;
    gLastCode = code; gLastTime = now;
    NSString *answer = e[gMode == 1 ? 0 : 1];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kTypeDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        faType(answer);
    });
}

// ---------- مراقبة نصوص الدردشة (swizzle على UILabel) ----------
static void (*orig_setText)(UILabel *, SEL, NSString *);
static void (*orig_setAttr)(UILabel *, SEL, NSAttributedString *);
static void new_setText(UILabel *self, SEL _cmd, NSString *t) { orig_setText(self, _cmd, t); faCheck(t); }
static void new_setAttr(UILabel *self, SEL _cmd, NSAttributedString *t) { orig_setAttr(self, _cmd, t); faCheck(t.string); }

// ملاحظة: لا يوجد زر عائم هنا ولا إضافة تلقائية لنافذة — التحكم صار بالكامل من قسم
// "اجوبة الأعلام" داخل منيو AflatoonSuite عبر FA_SetMode()، فلا تتكرر الواجهات.
__attribute__((constructor)) static void faInit() {
    Method m1 = class_getInstanceMethod(UILabel.class, @selector(setText:));
    orig_setText = (void (*)(UILabel *, SEL, NSString *))method_getImplementation(m1);
    method_setImplementation(m1, (IMP)new_setText);
    Method m2 = class_getInstanceMethod(UILabel.class, @selector(setAttributedText:));
    orig_setAttr = (void (*)(UILabel *, SEL, NSAttributedString *))method_getImplementation(m2);
    method_setImplementation(m2, (IMP)new_setAttr);
}
