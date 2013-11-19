#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSWindowController <NSWindowDelegate>
{
    IBOutlet NSTextField* site;
    IBOutlet NSTextField* domain;
    IBOutlet NSButton* download;
    IBOutlet NSTextField* level;
    IBOutlet NSButton* media;
    IBOutlet NSButton* editor;
    IBOutlet NSButton* php;
    IBOutlet NSProgressIndicator *loading;
    IBOutlet NSProgressIndicator *progress;
    IBOutlet NSTextField* percent;
}

- (IBAction) download_Click:(id)sender;
- (void) Debug:(NSString*)d;

@end
