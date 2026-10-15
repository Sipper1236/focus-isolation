// Native Chromium/CEF off-screen feasibility prototype. Isolation is unverified.
#import <Cocoa/Cocoa.h>
#include "include/cef_app.h"
#include "include/cef_application_mac.h"
#include "include/cef_browser.h"
#include "include/cef_client.h"
#include "include/cef_life_span_handler.h"
#include "include/cef_render_handler.h"
#include "include/cef_display_handler.h"
#include "include/cef_load_handler.h"
#include "include/cef_request_handler.h"
#include "include/cef_download_handler.h"
#include "include/cef_download_item.h"
#include "include/wrapper/cef_helpers.h"
#include "include/wrapper/cef_library_loader.h"
#include <sys/file.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <algorithm>
#include <cstring>
#include <vector>

@class BrowserController;
static int reportFD = -1;
static NSString* profileRoot;
static bool smokeMode=false;
static void SmokeResult(bool passed, NSString* reason) {
  NSDictionary* result=@{@"passed":@(passed),@"reason":reason,
      @"scope":@"Build, browser launch and page painting only. Not focus acceptance."};
  NSData* data=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:NULL];
  [data writeToFile:[profileRoot stringByAppendingPathComponent:@"native-build-smoke.json"] atomically:YES];
}
static void Observe(NSString* event) {
  if (reportFD < 0) return;
  NSDictionary* row = @{ @"type":event,
      @"wallMs":@([[NSDate date] timeIntervalSince1970]*1000),
      @"uptimeMs":@([[NSProcessInfo processInfo] systemUptime]*1000) };
  NSData* data = [NSJSONSerialization dataWithJSONObject:row options:0 error:nil];
  bool ok = data && write(reportFD, data.bytes, data.length) == (ssize_t)data.length;
  ok = ok && write(reportFD, "\n", 1) == 1;
  if (!ok) NSLog(@"Host observation log failed; acceptance run invalid.");
}
static uint32_t Mods(NSEvent* event) {
  NSUInteger f = event.modifierFlags;
  uint32_t m = 0;
  if (f & NSEventModifierFlagShift) m |= EVENTFLAG_SHIFT_DOWN;
  if (f & NSEventModifierFlagControl) m |= EVENTFLAG_CONTROL_DOWN;
  if (f & NSEventModifierFlagOption) m |= EVENTFLAG_ALT_DOWN;
  if (f & NSEventModifierFlagCommand) m |= EVENTFLAG_COMMAND_DOWN;
  if (f & NSEventModifierFlagCapsLock) m |= EVENTFLAG_CAPS_LOCK_ON;
  if ([NSEvent pressedMouseButtons] & 1) m |= EVENTFLAG_LEFT_MOUSE_BUTTON;
  if ([NSEvent pressedMouseButtons] & 2) m |= EVENTFLAG_RIGHT_MOUSE_BUTTON;
  if ([NSEvent pressedMouseButtons] & 4) m |= EVENTFLAG_MIDDLE_MOUSE_BUTTON;
  return m;
}
static CefRange Range(NSRange range) {
  return range.location == NSNotFound ? CefRange(UINT32_MAX, UINT32_MAX)
       : CefRange((uint32_t)range.location, (uint32_t)NSMaxRange(range));
}
static int WindowsKey(NSEvent* event) {
  switch (event.keyCode) {
    case 36: case 76: return 13;
    case 48: return 9;
    case 51: return 8;
    case 53: return 27;
    case 117: return 46;
    case 123: return 37;
    case 124: return 39;
    case 125: return 40;
    case 126: return 38;
    case 115: return 36;
    case 119: return 35;
    case 116: return 33;
    case 121: return 34;
    default: break;
  }
  NSString* text = event.charactersIgnoringModifiers.uppercaseString;
  return text.length ? [text characterAtIndex:0] : 0;
}

@interface BrowserView : NSView <NSTextInputClient> {
 @public
  CefRefPtr<CefBrowser> browser;
  std::vector<unsigned char> pixels;
  std::vector<unsigned char> popupPixels;
  int pixelWidth, pixelHeight, popupWidth, popupHeight;
  CefRect popupRect;
  BOOL popupVisible;
  NSString* marked;
  NSRange selection;
  CefRect caret;
}
- (void)paint:(const void*)buffer width:(int)w height:(int)h popup:(BOOL)isPopup;
- (CefMouseEvent)mouse:(NSEvent*)event;
@end

@interface BrowserController : NSObject <NSWindowDelegate, NSTextFieldDelegate, NSApplicationDelegate> {
 @public
  CefRefPtr<CefBrowser> browser;
}
@property(nonatomic,strong) NSWindow* window;
@property(nonatomic,strong) BrowserView* surface;
@property(nonatomic,strong) NSTextField* address;
@property(nonatomic,strong) NSTextField* status;
@property(nonatomic,strong) NSButton* backButton;
@property(nonatomic,strong) NSButton* forwardButton;
@property(nonatomic,strong) id activity;
@property(nonatomic,strong) NSMutableArray* observers;
- (void)show;
- (void)home:(id)sender;
- (void)closeBrowser;
@end

class BrowserClient : public CefClient, public CefRenderHandler,
    public CefLifeSpanHandler, public CefDisplayHandler, public CefLoadHandler,
    public CefRequestHandler, public CefDownloadHandler {
 public:
  explicit BrowserClient(BrowserController* owner) : owner_(owner) {}
  CefRefPtr<CefRenderHandler> GetRenderHandler() override { return this; }
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
  CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }
  CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }
  CefRefPtr<CefRequestHandler> GetRequestHandler() override { return this; }
  CefRefPtr<CefDownloadHandler> GetDownloadHandler() override { return this; }
  bool OnBeforeDownload(CefRefPtr<CefBrowser>, CefRefPtr<CefDownloadItem>,
      const CefString& name, CefRefPtr<CefBeforeDownloadCallback> callback) override {
    // Always ask the user where to save, including explicit diagnostic exports.
    callback->Continue(name,true);
    return true;
  }
  void OnDownloadUpdated(CefRefPtr<CefBrowser>, CefRefPtr<CefDownloadItem> item,
      CefRefPtr<CefDownloadItemCallback>) override {
    if (item->IsComplete()) owner_.status.stringValue=@"Download saved • Focus isolation unverified";
    else if (item->IsCanceled()) owner_.status.stringValue=@"Download canceled • Focus isolation unverified";
  }
  void GetViewRect(CefRefPtr<CefBrowser>, CefRect& rect) override {
    NSRect r = owner_.surface.bounds;
    rect = CefRect(0, 0, std::max(1, (int)r.size.width), std::max(1, (int)r.size.height));
  }
  bool GetScreenInfo(CefRefPtr<CefBrowser> b, CefScreenInfo& info) override {
    info.device_scale_factor = owner_.window.backingScaleFactor;
    info.depth = 32; info.depth_per_component = 8;
    CefRect rect;
    GetViewRect(b, rect); info.rect=rect; info.available_rect=rect;
    return true;
  }
  bool GetScreenPoint(CefRefPtr<CefBrowser>, int x, int y, int& sx, int& sy) override {
    NSPoint p = [owner_.surface convertPoint:NSMakePoint(x,y) toView:nil];
    p = [owner_.window convertPointToScreen:p];
    sx = (int)p.x;
    sy = (int)(NSScreen.screens[0].frame.size.height-p.y);
    return true;
  }
  void OnPaint(CefRefPtr<CefBrowser>, PaintElementType type,
      const RectList&, const void* buffer, int width, int height) override {
    [owner_.surface paint:buffer width:width height:height popup:type==PET_POPUP];
    if (type==PET_VIEW && width>0 && height>0) painted_=true;
    FinishSmoke();
  }
  void OnPopupShow(CefRefPtr<CefBrowser>, bool show) override {
    owner_.surface->popupVisible = show; [owner_.surface setNeedsDisplay:YES];
  }
  void OnPopupSize(CefRefPtr<CefBrowser>, const CefRect& rect) override {
    owner_.surface->popupRect = rect;
  }
  void OnImeCompositionRangeChanged(CefRefPtr<CefBrowser>, const CefRange&,
      const RectList& bounds) override {
    if (!bounds.empty()) owner_.surface->caret = bounds.back();
  }
  bool OnCursorChange(CefRefPtr<CefBrowser>, CefCursorHandle cursor,
      cef_cursor_type_t, const CefCursorInfo&) override {
    if (cursor) [(__bridge NSCursor*)cursor set];
    return true;
  }
  void OnAfterCreated(CefRefPtr<CefBrowser> b) override {
    BrowserController* owner=owner_;
    owner->browser = b; owner.surface->browser = b;
    b->GetHost()->SetFocus(true);
    Observe(@"engine-focus-set");
    [owner_.window makeFirstResponder:owner_.surface];
    Observe(@"browser-created");
  }
  void OnBeforeClose(CefRefPtr<CefBrowser>) override {
    Observe(@"browser-closed");
    BrowserController* owner=owner_;
    owner.surface->browser = nullptr; owner->browser = nullptr;
    CefQuitMessageLoop();
  }
  bool OnBeforePopup(CefRefPtr<CefBrowser> b, CefRefPtr<CefFrame>, int,
      const CefString& url, const CefString&, WindowOpenDisposition, bool,
      const CefPopupFeatures&, CefWindowInfo&, CefRefPtr<CefClient>&,
      CefBrowserSettings&, CefRefPtr<CefDictionaryValue>&, bool*) override {
    // One browser surface: open links in this session. Popup login flows need testing.
    if (!url.empty()) b->GetMainFrame()->LoadURL(url);
    return true;
  }
  bool OnBeforeBrowse(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame>,
      CefRefPtr<CefRequest> request, bool, bool) override {
    NSString* url = [NSString stringWithUTF8String:request->GetURL().ToString().c_str()];
    NSURL* parsed = [NSURL URLWithString:url];
    if (!parsed.isFileURL) return false;
    NSString* allowed = [[[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"diagnostic"]
                         stringByResolvingSymlinksInPath] stringByAppendingString:@"/"];
    return ![parsed.URLByResolvingSymlinksInPath.path hasPrefix:allowed];
  }
  void OnAddressChange(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame> frame,
      const CefString& url) override {
    if (frame->IsMain()) owner_.address.stringValue =
        [NSString stringWithUTF8String:url.ToString().c_str()];
  }
  void OnLoadingStateChange(CefRefPtr<CefBrowser>, bool loading,
      bool canBack, bool canForward) override {
    owner_.backButton.enabled = canBack; owner_.forwardButton.enabled = canForward;
    owner_.status.stringValue = loading ? @"Loading… • Focus isolation unverified"
                                       : @"Focus isolation unverified • Native Chromium experiment";
  }
  void OnLoadEnd(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame> frame, int) override {
    if (frame->IsMain() && frame->GetURL().ToString().find("/diagnostic/index.html")!=std::string::npos) {
      loaded_=true; FinishSmoke();
    }
  }
  void OnLoadError(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame> frame,
      ErrorCode error, const CefString& text, const CefString&) override {
    if (frame->IsMain() && error!=ERR_ABORTED)
      owner_.status.stringValue = [NSString stringWithFormat:@"Load failed: %s • Isolation unverified",
                                  text.ToString().c_str()];
  }
 private:
  void FinishSmoke() {
    if (!smokeMode || !loaded_ || !painted_ || finished_) return;
    finished_=true;
    BrowserController* owner=owner_;
    dispatch_async(dispatch_get_main_queue(),^{
      SmokeResult(true,@"Bundled diagnostic loaded and Chromium delivered a painted frame.");
      [owner closeBrowser];
    });
  }
  bool loaded_=false, painted_=false, finished_=false;
  __weak BrowserController* owner_;
  IMPLEMENT_REFCOUNTING(BrowserClient);
};

@implementation BrowserView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder {
  if (browser) browser->GetHost()->SetFocus(true);
  return YES;
}
// AppKit deactivation must not be forwarded to Chromium as focus loss.
// Whether this suffices is the question being measured, not a guarantee.
- (void)setFrameSize:(NSSize)size {
  [super setFrameSize:size];
  if (browser) browser->GetHost()->WasResized();
}
- (void)viewDidChangeBackingProperties {
  [super viewDidChangeBackingProperties];
  if (browser) { browser->GetHost()->NotifyScreenInfoChanged(); browser->GetHost()->WasResized(); }
}
- (void)paint:(const void*)buffer width:(int)w height:(int)h popup:(BOOL)isPopup {
  if (w<=0 || h<=0 || w>16384 || h>16384) return;
  auto& target = isPopup ? popupPixels : pixels;
  const auto* p = static_cast<const unsigned char*>(buffer);
  target.assign(p,p+(size_t)w*h*4);
  if (isPopup) { popupWidth=w; popupHeight=h; } else { pixelWidth=w; pixelHeight=h; }
  [self setNeedsDisplay:YES];
}
- (void)drawBuffer:(const std::vector<unsigned char>&)bytes width:(int)w
            height:(int)h rect:(NSRect)rect {
  if (bytes.empty()) return;
  // Copy snapshot so future renderer paints cannot mutate an active provider.
  CFDataRef data = CFDataCreate(kCFAllocatorDefault, bytes.data(), bytes.size());
  CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
  CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
  CGImageRef image = CGImageCreate(w,h,8,32,w*4,space,
      static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Little)|static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedFirst),
      provider,nullptr,false,kCGRenderingIntentDefault);
  if (image) {
    NSImage* bitmap = [[NSImage alloc] initWithCGImage:image size:rect.size];
    [bitmap drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationCopy
             fraction:1 respectFlipped:YES hints:nil];
    CGImageRelease(image);
  }
  CGColorSpaceRelease(space); CGDataProviderRelease(provider); CFRelease(data);
}
- (void)drawRect:(NSRect)dirty {
  [NSColor.whiteColor setFill]; NSRectFill(dirty);
  [self drawBuffer:pixels width:pixelWidth height:pixelHeight rect:self.bounds];
  if (popupVisible) [self drawBuffer:popupPixels width:popupWidth height:popupHeight
      rect:NSMakeRect(popupRect.x,popupRect.y,popupRect.width,popupRect.height)];
}
- (CefMouseEvent)mouse:(NSEvent*)event {
  NSPoint p=[self convertPoint:event.locationInWindow fromView:nil];
  CefMouseEvent m; m.x=(int)p.x; m.y=(int)p.y; m.modifiers=Mods(event); return m;
}
- (void)mouseDown:(NSEvent*)event {
  [self.window makeFirstResponder:self];
  if (browser) browser->GetHost()->SendMouseClickEvent([self mouse:event],MBT_LEFT,false,(int)event.clickCount);
}
- (void)mouseUp:(NSEvent*)event {
  if (browser) browser->GetHost()->SendMouseClickEvent([self mouse:event],MBT_LEFT,true,(int)event.clickCount);
}
- (void)rightMouseDown:(NSEvent*)event {
  [self.window makeFirstResponder:self];
  if (browser) browser->GetHost()->SendMouseClickEvent([self mouse:event],MBT_RIGHT,false,(int)event.clickCount);
}
- (void)rightMouseUp:(NSEvent*)event {
  if (browser) browser->GetHost()->SendMouseClickEvent([self mouse:event],MBT_RIGHT,true,(int)event.clickCount);
}
- (void)mouseMoved:(NSEvent*)event {
  if (browser) browser->GetHost()->SendMouseMoveEvent([self mouse:event],false);
}
- (void)mouseDragged:(NSEvent*)event { [self mouseMoved:event]; }
- (void)rightMouseDragged:(NSEvent*)event { [self mouseMoved:event]; }
- (void)scrollWheel:(NSEvent*)event {
  double scale=event.hasPreciseScrollingDeltas?1:40;
  if (browser) browser->GetHost()->SendMouseWheelEvent([self mouse:event],
      (int)(event.scrollingDeltaX*scale),(int)(event.scrollingDeltaY*scale));
}
- (void)keyDown:(NSEvent*)event {
  if (!browser) return;
  CefKeyEvent k; k.type=KEYEVENT_RAWKEYDOWN; k.modifiers=Mods(event);
  k.native_key_code=event.keyCode; k.windows_key_code=WindowsKey(event);
  browser->GetHost()->SendKeyEvent(k);
  // Real Cocoa input events drive composition; no activity is manufactured.
  [self interpretKeyEvents:@[event]];
}
- (void)keyUp:(NSEvent*)event {
  if (!browser) return;
  CefKeyEvent k; k.type=KEYEVENT_KEYUP; k.modifiers=Mods(event);
  k.native_key_code=event.keyCode; k.windows_key_code=WindowsKey(event);
  browser->GetHost()->SendKeyEvent(k);
}
- (BOOL)performKeyEquivalent:(NSEvent*)event {
  if (!browser || !(event.modifierFlags & NSEventModifierFlagCommand)) return NO;
  CefRefPtr<CefFrame> frame=browser->GetFocusedFrame();
  if (!frame) return NO;
  NSString* text=event.charactersIgnoringModifiers.lowercaseString;
  if ([text isEqualToString:@"c"]) frame->Copy();
  else if ([text isEqualToString:@"v"]) frame->Paste();
  else if ([text isEqualToString:@"x"]) frame->Cut();
  else if ([text isEqualToString:@"a"]) frame->SelectAll();
  else if ([text isEqualToString:@"z"]) frame->Undo();
  else return NO;
  return YES;
}
- (void)insertText:(id)text replacementRange:(NSRange)range {
  NSString* plain=[text isKindOfClass:NSAttributedString.class]?[text string]:text;
  if (browser) browser->GetHost()->ImeCommitText(CefString(plain.UTF8String),Range(range),0);
  marked=nil;
}
- (void)setMarkedText:(id)text selectedRange:(NSRange)selected replacementRange:(NSRange)range {
  marked=[text isKindOfClass:NSAttributedString.class]?[text string]:text;
  selection=selected;
  std::vector<CefCompositionUnderline> underlines;
  CefCompositionUnderline line; line.range=CefRange(0,(uint32_t)marked.length);
  line.color=0xFF000000; underlines.push_back(line);
  if (browser) browser->GetHost()->ImeSetComposition(CefString(marked.UTF8String),underlines,Range(range),Range(selected));
}
- (void)unmarkText { if (browser) browser->GetHost()->ImeFinishComposingText(false); marked=nil; }
- (BOOL)hasMarkedText { return marked.length>0; }
- (NSRange)markedRange { return marked.length?NSMakeRange(0,marked.length):NSMakeRange(NSNotFound,0); }
- (NSRange)selectedRange { return marked.length?selection:NSMakeRange(NSNotFound,0); }
- (NSArray<NSAttributedStringKey>*)validAttributesForMarkedText { return @[]; }
- (NSAttributedString*)attributedSubstringForProposedRange:(NSRange)range actualRange:(NSRangePointer)actual {
  if (actual) *actual=NSMakeRange(NSNotFound,0);
  return nil; // Surrounding-text IME reconversion is not implemented in this prototype.
}
- (NSUInteger)characterIndexForPoint:(NSPoint)point { return NSNotFound; }
- (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(NSRangePointer)actual {
  if (actual) *actual=range;
  NSRect r=NSMakeRect(caret.x,caret.y,std::max(1,caret.width),std::max(18,caret.height));
  return [self.window convertRectToScreen:[self convertRect:r toView:nil]];
}
- (void)doCommandBySelector:(SEL)selector {
  // Navigation/editing commands are already delivered as genuine raw key events.
  if (browser && selector==@selector(insertNewline:)) {
    CefKeyEvent event; event.type=KEYEVENT_CHAR;
    event.windows_key_code=13; event.character='\r'; event.unmodified_character='\r';
    browser->GetHost()->SendKeyEvent(event);
  }
}
@end

@implementation BrowserController
- (void)show {
  self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,1100,760)
      styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable
      backing:NSBackingStoreBuffered defer:NO];
  self.window.title=@"Focus Browser — experimental";
  self.window.delegate=self; self.window.releasedWhenClosed=NO;
  self.window.acceptsMouseMovedEvents=YES;
  NSView* root=self.window.contentView;
  self.surface=[[BrowserView alloc] initWithFrame:NSMakeRect(0,24,1100,688)];
  self.surface.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
  [root addSubview:self.surface];
  NSArray* titles=@[@"Back",@"Forward",@"Reload",@"Home"];
  NSArray* actions=@[NSStringFromSelector(@selector(back:)),NSStringFromSelector(@selector(forward:)),
                     NSStringFromSelector(@selector(reload:)),NSStringFromSelector(@selector(home:))];
  for (NSUInteger i=0;i<4;i++) {
    NSButton* button=[NSButton buttonWithTitle:titles[i] target:self action:NSSelectorFromString(actions[i])];
    button.frame=NSMakeRect(8+i*76,720,72,28); button.autoresizingMask=NSViewMinYMargin;
    [root addSubview:button];
    if (i==0) self.backButton=button;
    if (i==1) self.forwardButton=button;
  }
  self.address=[[NSTextField alloc] initWithFrame:NSMakeRect(318,720,774,28)];
  self.address.autoresizingMask=NSViewWidthSizable|NSViewMinYMargin;
  self.address.placeholderString=@"Enter an HTTPS address";
  self.address.target=self; self.address.action=@selector(navigate:); self.address.delegate=self;
  [root addSubview:self.address];
  self.status=[NSTextField labelWithString:@"Starting Chromium… • Focus isolation unverified"];
  self.status.frame=NSMakeRect(10,2,1080,20); self.status.autoresizingMask=NSViewWidthSizable;
  [root addSubview:self.status];
  NSMenu* menu=[[NSMenu alloc] init]; NSMenuItem* appItem=[[NSMenuItem alloc] init]; [menu addItem:appItem];
  NSMenu* submenu=[[NSMenu alloc] init]; appItem.submenu=submenu;
  for (NSArray* item in @[@[@"Show Host Reports",NSStringFromSelector(@selector(reports:)),@""],
                         @[@"Focus Address Bar",NSStringFromSelector(@selector(focusAddress:)),@"l"],
                         @[@"Quit Focus Browser",NSStringFromSelector(@selector(quit:)),@"q"]]) {
    NSMenuItem* entry=[[NSMenuItem alloc] initWithTitle:item[0] action:NSSelectorFromString(item[1]) keyEquivalent:item[2]];
    entry.target=self; [submenu addItem:entry];
  }
  NSApp.mainMenu=menu;
  self.observers=[[NSMutableArray alloc] init];
  for (NSArray* pair in @[@[NSApplicationDidResignActiveNotification,@"host-inactive"],
                         @[NSApplicationDidBecomeActiveNotification,@"host-active"]]) {
    id token=[NSNotificationCenter.defaultCenter addObserverForName:pair[0] object:NSApp queue:NSOperationQueue.mainQueue
      usingBlock:^(NSNotification* note) { Observe(pair[1]); }];
    [self.observers addObject:token];
  }
  for (NSArray* pair in @[@[NSWorkspaceWillSleepNotification,@"host-sleep"],
                         @[NSWorkspaceDidWakeNotification,@"host-wake"]]) {
    id token=[NSWorkspace.sharedWorkspace.notificationCenter addObserverForName:pair[0] object:nil
      queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification* note) { Observe(pair[1]); }];
    [self.observers addObject:token];
  }
  self.activity=[NSProcessInfo.processInfo beginActivityWithOptions:NSActivityUserInitiated
      reason:@"Measure Chromium while switching host applications"];
  [self.window center]; [self.window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
  CefWindowInfo info;
  info.SetAsWindowless((__bridge CefWindowHandle)self.surface);
  CefBrowserSettings settings; settings.windowless_frame_rate=30;
  NSString* path=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"diagnostic/index.html"];
  CefBrowserHost::CreateBrowser(info,new BrowserClient(self),
      CefString([NSURL fileURLWithPath:path].absoluteString.UTF8String),settings,nullptr,nullptr);
  Observe(@"probe-start");
}
- (void)navigate:(id)sender {
  if (!browser) return;
  NSString* address=[self.address.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (!address.length) return;
  if (![address containsString:@"://"]) address=[@"https://" stringByAppendingString:address];
  NSURL* url=[NSURL URLWithString:address];
  bool internal=[address isEqualToString:@"chrome://sandbox"] || [address isEqualToString:@"chrome://version"];
  if (!internal && ![@[@"http",@"https"] containsObject:url.scheme.lowercaseString]) {
    self.status.stringValue=@"Use an HTTP or HTTPS address."; return;
  }
  browser->GetMainFrame()->LoadURL(CefString(address.UTF8String));
  [self.window makeFirstResponder:self.surface];
}
- (void)controlTextDidBeginEditing:(NSNotification*)note {
  // Choosing browser chrome is a deliberate in-app focus change.
  if (browser) browser->GetHost()->SetFocus(false);
}
- (void)back:(id)sender { if (browser) browser->GoBack(); [self.window makeFirstResponder:self.surface]; }
- (void)forward:(id)sender { if (browser) browser->GoForward(); [self.window makeFirstResponder:self.surface]; }
- (void)reload:(id)sender { if (browser) browser->Reload(); [self.window makeFirstResponder:self.surface]; }
- (void)home:(id)sender {
  if (browser) {
    NSString* path=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"diagnostic/index.html"];
    browser->GetMainFrame()->LoadURL(CefString([NSURL fileURLWithPath:path].absoluteString.UTF8String));
  }
  [self.window makeFirstResponder:self.surface];
}
- (void)focusAddress:(id)sender { [self.window makeFirstResponder:self.address]; [self.address selectText:nil]; }
- (void)reports:(id)sender { [NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:profileRoot]]; }
- (void)quit:(id)sender { [self closeBrowser]; }
- (void)closeBrowser { if (browser) browser->GetHost()->CloseBrowser(false); else CefQuitMessageLoop(); }
- (BOOL)windowShouldClose:(NSWindow*)window { [self closeBrowser]; return NO; }
@end

@interface FocusApplication : NSApplication <CefAppProtocol> {
  BOOL handlingEvent;
}
@end
@implementation FocusApplication
- (BOOL)isHandlingSendEvent { return handlingEvent; }
- (void)setHandlingSendEvent:(BOOL)value { handlingEvent=value; }
- (void)sendEvent:(NSEvent*)event { CefScopedSendingEvent sending; [super sendEvent:event]; }
- (void)terminate:(id)sender { [(BrowserController*)self.delegate closeBrowser]; }
@end

class FocusApp : public CefApp, public CefBrowserProcessHandler {
 public:
  explicit FocusApp(BrowserController* owner):owner_(owner) {}
  CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override { return this; }
  void OnContextInitialized() override { [owner_ show]; }
 private:
  __weak BrowserController* owner_;
  IMPLEMENT_REFCOUNTING(FocusApp);
};

int main(int argc,char* argv[]) {
  for (int i=1;i<argc;i++) if (strcmp(argv[i],"--smoke")==0) smokeMode=true;
  CefScopedLibraryLoader loader;
  if (!loader.LoadInMain()) return 1;
  @autoreleasepool {
    [FocusApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    profileRoot=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/FocusBrowser"];
    NSError* error=nil;
    if (![NSFileManager.defaultManager createDirectoryAtPath:profileRoot withIntermediateDirectories:YES
         attributes:@{NSFilePosixPermissions:@0700} error:&error]) return 1;
    int lockFD=open([profileRoot stringByAppendingPathComponent:@"session.lock"].fileSystemRepresentation,O_CREAT|O_RDWR,0600);
    if (lockFD<0 || flock(lockFD,LOCK_EX|LOCK_NB)!=0) {
      NSAlert* alert=[[NSAlert alloc] init]; alert.messageText=@"Focus Browser is already running";
      alert.informativeText=@"Only one isolated profile session can run at a time."; [alert runModal];
      if (lockFD>=0) close(lockFD); return 1;
    }
    NSString* log=[profileRoot stringByAppendingPathComponent:
        [NSString stringWithFormat:@"host-%@.jsonl",NSUUID.UUID.UUIDString]];
    reportFD=open(log.fileSystemRepresentation,O_CREAT|O_EXCL|O_WRONLY,0600);
    if (reportFD<0) { close(lockFD); return 1; }
    CefSettings settings;
    settings.windowless_rendering_enabled=true;
    settings.no_sandbox=false;
    settings.background_color=0xFFFFFFFF;
    CefString(&settings.root_cache_path)=profileRoot.fileSystemRepresentation;
    CefString(&settings.cache_path)=[profileRoot stringByAppendingPathComponent:@"ChromiumProfile"].fileSystemRepresentation;
    // No command-line overrides, third-party script injection, or activity emulation.
    settings.command_line_args_disabled=true;
    settings.log_severity=LOGSEVERITY_DISABLE;
    BrowserController* owner=[[BrowserController alloc] init];
    NSApp.delegate=owner;
    CefRefPtr<FocusApp> app=new FocusApp(owner);
    CefMainArgs args(argc,argv);
    if (!CefInitialize(args,settings,app,nullptr)) { close(reportFD); close(lockFD); return CefGetExitCode(); }
    if (smokeMode) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,45*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        SmokeResult(false,@"Timed out before the diagnostic loaded and painted.");
        [owner closeBrowser];
      });
    }
    CefRunMessageLoop();
    if (owner.activity) [NSProcessInfo.processInfo endActivity:owner.activity];
    Observe(@"probe-stop");
    CefShutdown();
    close(reportFD); close(lockFD);
  }
  return 0;
}
