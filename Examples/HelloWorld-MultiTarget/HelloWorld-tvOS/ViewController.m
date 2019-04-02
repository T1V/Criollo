//
//  ViewController.m
//  HelloWorld-tvOS
//
//  Created by Cătălin Stan on 23/10/2017.
//

#import "ViewController.h"
#import "AppDelegate.h"

@interface ViewController () <UITextViewDelegate>

@property (weak) AppDelegate* appDelegate;
@property (weak, nonatomic) IBOutlet UITextView *logTextView;
@property (weak, nonatomic) IBOutlet UIStackView *pathsStackView;

@property (weak) IBOutlet UIBarButtonItem *startItem;
@property (weak) IBOutlet UIBarButtonItem *stopItem;

@property (weak) IBOutlet UILabel *statusDetailsButton;

@property (assign) BOOL isScheduled;
@property (assign) CGFloat width;

@property (strong) NSDataDetector* linkChecker;

- (IBAction)startListening:(id)sender;
- (IBAction)stopListening:(id)sender;

@end

@implementation ViewController

- (dispatch_block_t)resetBlock {
    static dispatch_block_t resetBlock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        resetBlock = dispatch_block_create(DISPATCH_BLOCK_ASSIGN_CURRENT, ^{
            dispatch_barrier_async(self.appDelegate.isolationQueue, ^{
                self.statusDetailsButton.text = self.appDelegate.isDisconnected ? @"Press ▶︎ to start listening" : @"";
                [self.statusDetailsButton sizeToFit];
                self.isScheduled = NO;
            });
        });
    });
    return resetBlock;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.width = (self.logTextView.frame.size.width);
    
    self.appDelegate = [[UIApplication sharedApplication] delegate];
    [self.appDelegate addObserver:self forKeyPath:@"isConnected" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
    [self.appDelegate addObserver:self forKeyPath:@"isDisconnected" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
    
    NSError* linkCheckerError;
    self.linkChecker = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&linkCheckerError];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:LogMessageNotificationName object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
    
        dispatch_async(self.appDelegate.isolationQueue, ^{
            NSMutableAttributedString* attributedString = [note.object mutableCopy];
            
            NSArray<NSTextCheckingResult*>* matches = [self.linkChecker matchesInString:attributedString.string options:0 range:NSMakeRange(0, attributedString.length)];
            [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull match, NSUInteger idx, BOOL * _Nonnull stop) {
                [attributedString addAttribute:NSLinkAttributeName value:match.URL range:match.range];
            }];
            
            [self.logTextView.textStorage appendAttributedString:attributedString];
            [self.logTextView.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
            [self.logTextView scrollRangeToVisible:NSMakeRange(self.logTextView.text.length, 0)];
        });
    }];
    
    self.logTextView.linkTextAttributes = self.appDelegate.linkTextAttributes;
    [self.logTextView scrollRectToVisible:CGRectZero animated:NO];
        
    [self.appDelegate startListening:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self.appDelegate.server closeAllConnections:nil];
}

- (void)startListening:(id)sender {
    [self.appDelegate startListening:sender];
}

- (void)stopListening:(id)sender {
    [self.appDelegate stopListening:sender];
}


- (NSDictionary *)logCommonAtributes {
    static NSDictionary* logCommonAtributes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableParagraphStyle* style = [[NSMutableParagraphStyle alloc] init];
        style.lineHeightMultiple = 1.;
        style.lineBreakMode = NSLineBreakByTruncatingMiddle;
        
        NSMutableDictionary* tempDictionary = [NSMutableDictionary dictionaryWithDictionary:self.appDelegate.logDebugAtributes];
        tempDictionary[NSParagraphStyleAttributeName] = style;
        tempDictionary[NSFontAttributeName] = [UIFont fontWithName:@"Menlo" size:14.0f];
        
        logCommonAtributes = tempDictionary.copy;
    });
    return logCommonAtributes;
}

- (NSDictionary *)logResponseAtributes {
    static NSDictionary* logResponseAtributes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary* tempDictionary = [NSMutableDictionary dictionaryWithDictionary:[self logCommonAtributes]];
        tempDictionary[NSForegroundColorAttributeName] = [UIColor whiteColor];
        logResponseAtributes = tempDictionary.copy;
    });
    return logResponseAtributes;
}

- (NSDictionary *)logErrorAtributes {
    static NSDictionary* logErrorAtributes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary* tempDictionary = [NSMutableDictionary dictionaryWithDictionary:[self logCommonAtributes]];
        tempDictionary[NSForegroundColorAttributeName] = [UIColor orangeColor];
        logErrorAtributes = tempDictionary.copy;
    });
    return logErrorAtributes;
}

- (void)openURL:(UIButton *)sender {
    NSURL *url = [NSURL URLWithString: sender.titleLabel.text];
    [self postSuccessResponseString:[NSString stringWithFormat:@"Requesting: %@ ...", url]];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:60.f];
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if ( error != nil ) {
            [self postErrorResponseString:error.localizedDescription];
            return;
        }
        
        NSHTTPURLResponse *res = (NSHTTPURLResponse *)response;
        [self postSuccessResponseString:[NSString stringWithFormat:@"Response from: %@, HTTP %lu, %@ %lu bytes", res.URL, res.statusCode, res.MIMEType, data.length]];
        
        [self handleResponse:res withData:data];
    }] resume];
}

- (void)handleResponse:(NSHTTPURLResponse *)response withData:(NSData *)data {
    BOOL isErrorResponse = response.statusCode < 200 || response.statusCode > 399;
    if ( isErrorResponse ) {
        [self postErrorResponseString:[[NSString alloc] initWithBytesNoCopy:(void *)data.bytes length:data.length encoding:NSUTF8StringEncoding freeWhenDone:NO]];
        return;
    }
    
    if ( [response.MIMEType hasPrefix:@"image/"] ) {
        UIImage *image = [[UIImage alloc] initWithData:data];
        [self postImageResponse:image];
    }else if ( [response.MIMEType hasPrefix:@"text/html"] ) {
        [self postHTMLResponse:data];
    } else {
        NSString *string = [[NSString alloc] initWithBytesNoCopy:(void *)data.bytes length:data.length encoding:NSUTF8StringEncoding freeWhenDone:NO];
        [self postSuccessResponseString:string];
    }
}

- (void)postHTMLResponse:(NSData *)html {
    NSDictionary *options = @{ NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType, NSBackgroundColorAttributeName: UIColor.whiteColor};
    NSError *error;
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithData:html options:options documentAttributes:nil error:&error];
    if ( error != nil ) {
        [self postErrorResponseString:error.localizedDescription];
    } else {
        CGFloat scaleFactor = attributedString.size.width / self.width;
        UIGraphicsBeginImageContextWithOptions(attributedString.size, YES, scaleFactor);
        [UIColor.whiteColor setFill];
        CGContextFillRect(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, attributedString.size.width, attributedString.size.height));
        [attributedString drawAtPoint:CGPointZero];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        [self postImageResponse:image];
    }
}

- (void)postImageResponse:(UIImage *)image {
    NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
    textAttachment.image = image;
    CGFloat oldWidth = textAttachment.image.size.width;
    CGFloat scaleFactor = oldWidth / self.width;
    textAttachment.image = [UIImage imageWithCGImage:textAttachment.image.CGImage scale:scaleFactor orientation:UIImageOrientationUp];
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@"\n\n"];
    [attributedString insertAttributedString:[NSAttributedString attributedStringWithAttachment:textAttachment]  atIndex:1];
    [self postLogString:attributedString];
}

- (void)postSuccessResponseString:(NSString *)string {
    [self postResponseString:string attributes:[self logResponseAtributes]];
}

- (void)postErrorResponseString:(NSString *)string {
    [self postResponseString:string attributes:[self logErrorAtributes]];
}

- (void)postResponseString:(NSString *)string attributes:(NSDictionary *)attributes {
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:string attributes:attributes];
    [self postLogString:attributedString];
}

- (void)postLogString:(NSAttributedString *)attributedString {
    [NSNotificationCenter.defaultCenter postNotificationName:LogMessageNotificationName object:attributedString];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if ( [keyPath isEqualToString:@"isConnected"] || [keyPath isEqualToString:@"isDisconnected"] ) {
        
        if ( self.appDelegate.isConnected ) {
            
            [self.pathsStackView.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [obj removeFromSuperview];
            }];
            
            NSArray<NSString *> *paths = [[self.appDelegate.server valueForKeyPath:@"routes.@distinctUnionOfObjects.path"] sortedArrayUsingSelector:@selector(compare:)];
            [paths enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
                [button setTitle:[self.appDelegate.baseURL URLByAppendingPathComponent:[obj substringFromIndex:1]].absoluteString forState:UIControlStateNormal];
                [button addTarget:self action:@selector(openURL:) forControlEvents:UIControlEventAllEvents];
                [self.pathsStackView addArrangedSubview:button];
            }];
            [self.pathsStackView layoutSubviews];
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            
            
            NSString* statusText = @"";
            if ( self.appDelegate.isDisconnected ) {
                statusText = @"Disconnected";
            } else {
                if ( self.appDelegate.isConnected ) {
                    statusText = @"Connected. Waiting for requests ...";
                } else {
                    statusText = @"";
                }
            }
            
            
            if ( self.isScheduled ) {
                dispatch_block_cancel(self.resetBlock);
            }
            self.isScheduled = YES;
            dispatch_async(self.appDelegate.isolationQueue, ^{
                self.statusDetailsButton.text = statusText;
                [self.statusDetailsButton sizeToFit];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), self.appDelegate.isolationQueue, self.resetBlock);
                self.startItem.enabled = self.appDelegate.isDisconnected;
                self.stopItem.enabled = self.appDelegate.isConnected;
            });
        });
    }
}

- (void)dealloc {
    [self.appDelegate removeObserver:self forKeyPath:@"isConnected"];
    [self.appDelegate removeObserver:self forKeyPath:@"isDisconnected"];
}

@end

