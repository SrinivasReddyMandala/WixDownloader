#import "AppDelegate.h"

@implementation AppDelegate

NSThread *thread;
NSString* DownloadPath;
NSMutableSet* Bandwidth;
NSArray* http;
NSArray* allowedDomains;
NSArray* binExtentions;
NSArray* txtExtentions;
NSArray* jsExtentions;
NSArray* wixExtentions;
NSArray* wixTags;
NSArray* wixTagsURL;
NSString* skinURL;
NSString* webURL;
NSString* coreURL;
NSString* mediaURL;
NSTask* HTTPServer;

- (id) init
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:nil];
    return self;
}

- (void)windowWillClose:(NSNotification *)notification
{
    [HTTPServer terminate];
    [NSApp terminate:self];
}

-(NSString*)downloadFile:(NSString*)url
{
    BOOL allow = FALSE;
    for(int i = 0; i < [allowedDomains count]; i++)
    {
        if ([url rangeOfString:[allowedDomains objectAtIndex:i]].location != NSNotFound)
        {
            allow = TRUE;
            break;
        }
    }
    
    if ([url rangeOfString:@"editor" options:NSCaseInsensitiveSearch].location != NSNotFound && [editor state] != NSOnState)
    {
        //http://static.parastorage.com/services/skins/2.648.0/javascript/wysiwyg/viewer/skins/button/AdminLoginButtonSkin.js
        allow = FALSE;
    }
    
    if(allow && ![Bandwidth containsObject:url])
    {
        [Bandwidth addObject:url];
        //[self Debug:[NSString stringWithFormat:@"Downloading URL: %@", url]];
        
        NSHTTPURLResponse *urlResponse = nil;
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
        
        //Fool's day incoming folks
        [request setHTTPMethod:@"GET"];
        [request addValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:25.0) Gecko/20100101 Firefox/25.0" forHTTPHeaderField: @"User-Agent"];
        
        //Usually a good idea, as a security measure some files can be protected if no refferer
        //http://en.wikipedia.org/wiki/HTTP_referer
        [request addValue:url forHTTPHeaderField: @"Referer"];
        
        NSData *indexData = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:nil];
        
        if ([urlResponse statusCode] == 200)
        {
            //[Bandwidth addObject:url];
            return [[NSString alloc] initWithData:indexData encoding:NSUTF8StringEncoding];
        }
        else  if ([urlResponse statusCode] == 301)
        {
            [self Debug:[NSString stringWithFormat:@"302 Moved > %@", [[NSString alloc] initWithData:indexData encoding:NSUTF8StringEncoding]]];
            //TODO catch "Server:" reply
            //_api/dynamicmodel
        }
        else
        {
            //[self Debug:[NSString stringWithFormat:@"Downloading ERROR (%ld): %@", [urlResponse statusCode], url]];
        }
        
    }
    return NULL;
}

- (NSData*) ServerPWN
{
    return NULL;
}

-(void)startThread
{
    NSError * error = nil;
    
    //==== Propriotery to wix.com ======
    allowedDomains = [NSArray arrayWithObjects: @"wix.com", @"parastorage.com", @"wixstatic.com", @"wixpress.com", [site stringValue], nil];
    wixExtentions = [NSArray arrayWithObjects: @"wysiwyg", @"skins", @"core", @"web", @"wixapps", nil];
    //==================================
    
    http = [NSArray arrayWithObjects: @"http://", @"https://", nil];
    binExtentions = [NSArray arrayWithObjects: @"ico", @"png", @"jpg", @"jpeg", @"gif", @"mp3", @"wix_mp", @"swf", @"html", @"htm", nil]; //wix_mp = png
    txtExtentions = [NSArray arrayWithObjects: @"js", @"json", @"z", @"css", nil];
    jsExtentions = [NSArray arrayWithObjects: @"url", @"uri",  @"background-image:url", @"background:url", @"iconUrl", nil];
    
    DownloadPath = [NSString stringWithFormat:@"%@/Downloads/%@",NSHomeDirectory(),[[domain stringValue] stringByReplacingOccurrencesOfString:@"http://" withString:@""]];
    
    NSString *indexHTML = [self downloadFile:[site stringValue]];
    NSString *indexADS = [[NSString alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/Contents/Resources/ads.html",[[NSBundle mainBundle] bundlePath]] encoding:NSUTF8StringEncoding error:&error];
    
    //Prevent ":" in the directory name as port#
    DownloadPath = [DownloadPath stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    [[NSFileManager defaultManager] createDirectoryAtPath:DownloadPath withIntermediateDirectories:NO attributes:nil error:&error];
    
    //Save original
    indexHTML = [indexHTML stringByReplacingOccurrencesOfString:indexADS withString:@""]; //Remove Ads
    [indexHTML writeToFile:[NSString stringWithFormat:@"%@/index.original.html",DownloadPath] atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    //Yes Son! split it
    NSArray *jsonHTTP = [indexHTML componentsSeparatedByString: @"\""];
    [progress setMaxValue:[jsonHTTP count]];
    
    //==== Propriotery to wix.com ======
    for(int i = 0; i < [jsonHTTP count]; i++)  //Get static URLs dynamically
    {
        if ([[jsonHTTP objectAtIndex:i] isEqualToString:@"skins"])
        {
            skinURL = [jsonHTTP objectAtIndex:i+2];
        }
        else if ([[jsonHTTP objectAtIndex:i] isEqualToString:@"web"])
        {
            webURL = [jsonHTTP objectAtIndex:i+2];
        }
        else if ([[jsonHTTP objectAtIndex:i] isEqualToString:@"core"])
        {
            coreURL = [jsonHTTP objectAtIndex:i+2];
        }
        else if ([[jsonHTTP objectAtIndex:i] isEqualToString:@"staticMediaUrl"])
        {
            mediaURL = [jsonHTTP objectAtIndex:i+2];
        }
    }
    
    wixTags = [NSArray arrayWithObjects: @"[tdr]",@"[baseThemeDir]" @"[webThemeDir]", @"[themeDir]", @"[ulc]", @"SKIN_ICON_PATH+", nil];
    wixTagsURL = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%@/images/wysiwyg/core/themes/base/",skinURL], [NSString stringWithFormat:@"%@/images/wysiwyg/core/themes/base/",skinURL], @"/", @"/", @"/", @"/", nil];
    
    //http://static.parastorage.com/services/skins/2.648.1/images/wysiwyg/core/themes/base/shadowbottom.png
    //TODO: Wireshark these out ...find the URLS
    //[tdr],[baseThemeDir]      =   BASE_THEME_DIRECTORY
    //[themeDir]                =   THEME_DIRECTORY
    //[webThemeDir]             =   WEB_THEME_DIRECTORY
    //==================================
    
    
    for(int i = 0; i < [jsonHTTP count]; i++)
    {
        if ([[jsonHTTP objectAtIndex:i] rangeOfString:@"http://"].location != NSNotFound)
        {
            if([[NSThread currentThread] isCancelled])
                [NSThread exit];
            
            //===================================
            NSString* dirRoot = [[NSString alloc] init];
            NSString* fileDownload = [jsonHTTP objectAtIndex:i];
            NSArray* domainRoot = [[fileDownload stringByReplacingOccurrencesOfString:@"http://" withString:@""] componentsSeparatedByString: @"/"];
            
            /*
             for(int d = 1; d < [domainRoot count]; d++) //we only need first and last
             {
             dirRoot = [dirRoot stringByAppendingString:[NSString stringWithFormat:@"%@/",[domainRoot objectAtIndex:d]]];
             //=========== index.json ============
             // This is tricky to detect, but wix has many index.json
             // hidden in directories, make sure we don't miss them
             if ([dirRoot rangeOfString:@"?"].location == NSNotFound && [[dirRoot pathExtension] length] < 3)
             {
             [self fileAnalyzer:[NSString stringWithFormat:@"http://%@/%@index.json",[domainRoot objectAtIndex:0],dirRoot] :@"index.json" :1];
             }
             //=========== index.json ============
             }
             */
            
            dirRoot = [self pathFromURL:fileDownload];
            
            [self fileAnalyzer:[NSString stringWithFormat:@"http://%@/%@index.json",[domainRoot objectAtIndex:0],dirRoot] :@"index.json" :1];
            
            [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/%@",DownloadPath,dirRoot] withIntermediateDirectories:YES attributes:nil error:&error];
            
            
            NSString* fileRoot = [domainRoot objectAtIndex:[domainRoot count]-1];
            //Get rid of ? in the filename. This is ussually means the the file at the server is dynamic. like a PHP script but we don't care, we need static
            if ([fileRoot rangeOfString:@"?"].location != NSNotFound)
            {
                NSArray* staticFile = [fileRoot componentsSeparatedByString: @"?"];
                fileRoot = [staticFile objectAtIndex:0];
            }
            //===================================
            
            if([binExtentions containsObject:[fileRoot pathExtension]]) //binary files, no analisys needed
            {
                NSData* webBinary = [NSData dataWithContentsOfURL:[NSURL URLWithString:[jsonHTTP objectAtIndex:i]]];
                
                //[self Debug:[NSString stringWithFormat:@"Downloading Binary: %@", fileRoot]];
                
                if ([webBinary writeToFile:[NSString stringWithFormat:@"%@/%@/%@",DownloadPath,dirRoot,fileRoot] atomically:YES])
                {
                    //[self Debug:[NSString stringWithFormat:@"Saved %@", fileRoot]];
                }
            }
            else
            {
                [self fileAnalyzer:fileDownload :fileRoot :1];
            }
            
            BOOL replace = YES;
            
            if ([[jsonHTTP objectAtIndex:i-2] isEqualToString:@"emailServer"])
            {
                replace = NO;
            }
            
            if ([php state] == NSOnState)  //TODO: create emulating email php?
            {
                NSString* invokePHP = @"<?php\
                ?>";
                [invokePHP writeToFile:[NSString stringWithFormat:@"%@/common-services/notification/invoke",DownloadPath] atomically:YES encoding:NSUTF8StringEncoding error:nil];
            }
            
            if ([media state] != NSOnState)
            {
                if ([[jsonHTTP objectAtIndex:i-2] isEqualToString:@"mediaRootUrl"] ||
                    [[jsonHTTP objectAtIndex:i-2] isEqualToString:@"staticMediaUrl"] ||
                    [[jsonHTTP objectAtIndex:i-2] isEqualToString:@"staticAudioUrl"])
                {
                    //NSLog(@">> %@",[jsonHTTP objectAtIndex:i-2]);
                    replace = NO;
                }
            }
            
            if(replace == YES)
            {
                if(![binExtentions containsObject:[fileRoot pathExtension]] && ![txtExtentions containsObject:[fileRoot pathExtension]])
                {
                    fileRoot = @"";
                }
                
                //[self Debug:[NSString stringWithFormat:@"Replace %@ > %@", fileDownload,[NSString stringWithFormat:@"%@/%@/%@",[domain stringValue],dirRoot,fileRoot]]];
                
                indexHTML = [indexHTML stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\"%@\"",fileDownload] withString:[self http_correctURL:[NSString stringWithFormat:@"\"%@/%@/%@\"",[domain stringValue],dirRoot,fileRoot]]];
            }
        }
        
        float totalcount = [jsonHTTP count];
        float currentcount = i;
        [percent setStringValue:[NSString stringWithFormat:@"%.1f %%", currentcount / totalcount * 100]];
        [progress setDoubleValue:i];
    }
    
    //Replace important static entries
    //===================================
    indexHTML = [indexHTML stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\"domain\":\"%@\"",[[site stringValue] stringByReplacingOccurrencesOfString:@"http://" withString:@""]] withString:[NSString stringWithFormat:@"\"domain\":\"%@\"",[[domain stringValue] stringByReplacingOccurrencesOfString:@"http://" withString:@""]]];
    
    //indexHTML = [indexHTML stringByReplacingOccurrencesOfString:@"\"baseDomain\":\"wix.com\"" withString:[NSString stringWithFormat:@"\"baseDomain\":\"%@\"",[[[domain stringValue] stringByReplacingOccurrencesOfString:@"http://" withString:@""] stringByReplacingOccurrencesOfString:@"www." withString:@""]]];
    indexHTML = [indexHTML stringByReplacingOccurrencesOfString:@"\"baseDomain\":\"wix.com\"" withString:@"\"baseDomain\":\"/\""];
    //===================================
    
    if ([php state] == NSOnState)
    {
        [indexHTML writeToFile:[NSString stringWithFormat:@"%@/index.php",DownloadPath] atomically:YES encoding:NSUTF8StringEncoding error:&error];
    }
    else
    {
        [indexHTML writeToFile:[NSString stringWithFormat:@"%@/index.html",DownloadPath] atomically:YES encoding:NSUTF8StringEncoding error:&error];
    }
    
    //TODO: Crawl for Ajax SEO pages
    
    //Cleanup empty folders
    system([[NSString stringWithFormat:@"find %@ -type d -empty -delete",DownloadPath] UTF8String]);
    
    //Remove other not interesting folders
    system([[NSString stringWithFormat:@"rm -r %@/new",DownloadPath] UTF8String]);
    system([[NSString stringWithFormat:@"rm -r %@/create",DownloadPath] UTF8String]);
    system([[NSString stringWithFormat:@"rm -r %@/plebs",DownloadPath] UTF8String]);
    system([[NSString stringWithFormat:@"rm -r %@/portal",DownloadPath] UTF8String]);
    system([[NSString stringWithFormat:@"rm -r %@/integrations",DownloadPath] UTF8String]);
    //system([[NSString stringWithFormat:@"rm -r %@/wix-html-editor-pages-webapp",DownloadPath] UTF8String]);
    //system([[NSString stringWithFormat:@"rm -r %@/wix-public-html-renderer",DownloadPath] UTF8String]);
    
    [self Debug:@"Downloading Finished"];
    [download setTitle:@"Download"];
    [loading stopAnimation: self];
    [loading setHidden:TRUE];
    [progress stopAnimation: self];
    
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:DownloadPath]]];
    
    // TODO: Looks like some "skin" graphics files are hidden deep inside java
    // do a server sweep and look for 404 requests on live Safari view.
    
    if ([[domain stringValue] rangeOfString:@"127.0.0.1:8000"].location != NSNotFound)
    {
        @try
        {
            [self Debug:@"Starting HTTPServer ..."];
            
            HTTPServer = [[NSTask alloc] init];
            NSPipe* pipe = [NSPipe pipe];
            NSFileHandle* file = [pipe fileHandleForReading];
            
            [HTTPServer setLaunchPath:@"/usr/bin/python"];
            [HTTPServer setArguments:@[@"-m", @"SimpleHTTPServer"]];
            [HTTPServer setCurrentDirectoryPath:DownloadPath];
            [HTTPServer launch];
            //[HTTPServer waitUntilExit];
            sleep(3);
            
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[[domain stringValue] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
            
            NSData* data;
            while((data=[file availableData]))
            {
                @try
                {
                    //NSArray* line = [fileRoot componentsSeparatedByString: @"/n"];
                    [self Debug:[NSString stringWithFormat:@"HTTPServer: %@", [NSString stringWithUTF8String:[data bytes]]]];
                }
                @catch (NSException *exception)
                {
                }
            }
        }
        @catch (NSException *exception)
        {
            [self Debug:[NSString stringWithFormat:@"HTTPServer Error: %@", exception]];
        }
    }
    
    [percent setStringValue:@"100 %"];
}

-(NSString*)http_correctURL:(NSString*)url
{
    url = [url stringByReplacingOccurrencesOfString:@"/./" withString:@"/"];
    while ([url rangeOfString:@"//"].location != NSNotFound)
    {
        url = [url stringByReplacingOccurrencesOfString:@"//" withString:@"/"];
    }
    url = [url stringByReplacingOccurrencesOfString:@"http:/" withString:@"http://"];
    
    return url;
}

-(void)fileAnalyzer:(NSString*)file :(NSString*)fileRoot :(int)_level
{
    //Apple Bug? when doing stringByDeletingLastPathComponent for URL it kicks out one of slash from http://
    file = [self http_correctURL: file];
    
    NSString* webfile = [self downloadFile:file];
    
    [self Debug:[NSString stringWithFormat:@"> File Analyzer: (%ld) %@ [%d]", [webfile length], file, _level]];
    
    if(webfile != NULL)
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/%@",DownloadPath,[self pathFromURL:file]] withIntermediateDirectories:YES attributes:nil error:nil];
        
        //[self Debug:[NSString stringWithFormat:@"Replace %@ > %@", file,[NSString stringWithFormat:@"%@/%@/%@",[domain stringValue],[self pathFromURL:file],fileRoot]]];
        webfile = [webfile stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\"%@\"",file] withString:[NSString stringWithFormat:@"\"%@/%@/%@\"",[domain stringValue],[self pathFromURL:file],fileRoot]];
        [webfile writeToFile:[NSString stringWithFormat:@"%@/%@/%@",DownloadPath,[self pathFromURL:file],fileRoot] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        NSArray *split;
        if(([[fileRoot pathExtension] isEqualToString:@"js"] || [[fileRoot pathExtension] isEqualToString:@"json"] || [[fileRoot pathExtension] isEqualToString:@"z"]) && _level <= [[level stringValue] intValue])
        {
            if ([webfile rangeOfString:@","].location != NSNotFound)
            {
                split = [webfile componentsSeparatedByString: @","];
            }
            else if ([webfile rangeOfString:@";"].location != NSNotFound)
            {
                split = [webfile componentsSeparatedByString: @";"];
            }
            
            for(int u = 0; u < [split count]; u++)
            {
                //==================
                NSArray* components;
                if ([[split objectAtIndex:u] rangeOfString:@"\""].location != NSNotFound)
                {
                    components = [[split objectAtIndex:u] componentsSeparatedByString: @"\""];
                }
                else if ([[split objectAtIndex:u] rangeOfString:@"("].location != NSNotFound)
                {
                    components = [[split objectAtIndex:u] componentsSeparatedByString: @"("];
                }
                //==================
                
                for(int i = 0; i < [components count]; i++)
                {
                    if ([[components objectAtIndex:i] rangeOfString:@";"].location != NSNotFound)
                    {
                        NSArray* _components = [[split objectAtIndex:u] componentsSeparatedByString: @";"];
                        for(int c = 0; c < [_components count]; c++)
                        {
                            @try //Required
                            {
                                [self deepAnalyzer:file :[_components objectAtIndex:c] :[_components objectAtIndex:c-1] :[_components objectAtIndex:c-2] :_level];
                            }
                            @catch (NSException* ex)
                            {
                            }
                        }
                    }
                    else
                    {
                        @try //Required
                        {
                            [self deepAnalyzer:file :[components objectAtIndex:i] :[components objectAtIndex:i-1] :[components objectAtIndex:i-2] :_level];
                        }
                        @catch (NSException* ex)
                        {
                        }
                    }
                }
            }
        }
    }
}

-(void)deepAnalyzer:(NSString*)file :(NSString*)_url :(NSString*)arg1 :(NSString*)arg2 :(int)_level
{
    _url = [self pathTagCleanup:_url];
    arg1 = [self pathTagCleanup:arg1];
    arg2 = [self pathTagCleanup:arg2];
    
    if ([_url rangeOfString:@"."].location != NSNotFound && [_url rangeOfString:@" "].location == NSNotFound && [_url rangeOfString:@"\n"].location == NSNotFound)
    {
        NSArray* parts = [_url componentsSeparatedByString: @"."];
        if([wixExtentions containsObject:[parts objectAtIndex:0]])
        {
            //Take care of brackets
            if ([_url rangeOfString:@"("].location != NSNotFound && [_url rangeOfString:@")"].location != NSNotFound)
            {
                NSArray* bktRight = [_url componentsSeparatedByString: @"("];
                NSArray* bktLeft = [[bktRight objectAtIndex:0] componentsSeparatedByString: @"("];
                _url = [bktLeft objectAtIndex:[bktLeft count]-1];
            }
            
            _url = [_url stringByReplacingOccurrencesOfString:@"." withString:@"/"];
            
            [self Debug:[NSString stringWithFormat:@"\tHidden JavaScript: %@.js",_url]];
            
            // Example:
            // wysiwyg.viewer.skins.VideoSkin > http://static.parastorage.com/services/skins/services/skins/2.648.0/javascript/wysiwyg/viewer/skins/VideoSkin.js
            // wysiwyg.viewer.components.WPhoto > http://static.parastorage.com/services/web/2.648.0/javascript/wysiwyg/viewer/components/WPhoto.js
            
            NSString* url =[file stringByDeletingLastPathComponent];
            NSString* ext = @".js";
            
            //same directory
            //[self fileAnalyzer:[NSString stringWithFormat:@"%@/javascript/%@.js",url ,_url] :[NSString stringWithFormat:@"%@.js",[_url lastPathComponent]]];
            
            //other logical places (no worries duplicates will be ignored)
            if ([_url rangeOfString:@"/skin" options:NSCaseInsensitiveSearch].location != NSNotFound)
            {
                url = skinURL;
            }
            else if ([_url rangeOfString:@"/core" options:NSCaseInsensitiveSearch].location != NSNotFound)
            {
                _url = [_url stringByReplacingOccurrencesOfString:@"mobile/" withString:@""]; // ..looks like "mobile" is being ignored in path
                url =  coreURL;
            }
            else if ([_url rangeOfString:@"/components" options:NSCaseInsensitiveSearch].location != NSNotFound)
            {
                url = webURL;
            }
            
            [self fileAnalyzer:[NSString stringWithFormat:@"%@/javascript/%@%@",url ,_url,ext] :[NSString stringWithFormat:@"%@%@",[_url lastPathComponent],ext] :_level+1];
        }
        else
        {
            if([jsExtentions containsObject:arg1] || [jsExtentions containsObject:arg2])
            {
                if([binExtentions containsObject:[_url pathExtension]]) //binary files, no analisys needed
                {
                    BOOL DLmedia = TRUE; //download skin images but not galleries.
                    
                    if ([_url rangeOfString:@"/media" options:NSCaseInsensitiveSearch].location != NSNotFound && [media state] != NSOnState)
                    {
                        DLmedia = FALSE;
                    }
                    
                    if(DLmedia)
                    {
                        //Replace [] with url
                        for(int t = 0; t < [wixTags count]; t++)
                        {
                            if ([_url rangeOfString:[wixTags objectAtIndex:t]].location != NSNotFound)
                            {
                                _url = [_url stringByReplacingOccurrencesOfString:[wixTags objectAtIndex:t] withString:[wixTagsURL objectAtIndex:t]];
                                break;
                            }
                        }
                        
                        [self Debug:[NSString stringWithFormat:@"\tHidden Media: %@", _url]];
                        
                        _url = [NSString stringWithFormat:@"%@/%@",mediaURL,_url];
                        
                        NSData* webBinary = [NSData dataWithContentsOfURL:[NSURL URLWithString:_url]];
                        
                        [[NSFileManager defaultManager] createDirectoryAtPath:[[NSString stringWithFormat:@"%@/%@",DownloadPath,[self pathFromURL:_url]] stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
                        
                        if ([webBinary writeToFile:[NSString stringWithFormat:@"%@/%@/%@",DownloadPath,[self pathFromURL:file],_url] atomically:YES])
                        {
                            //TODO: wix has a dynamic image by size, make php to emulate the same
                            if ([php state] == NSOnState)
                            {
                                
                            }
                        }
                    }
                }
                else if([txtExtentions containsObject:[_url pathExtension]])
                {
                    [self Debug:[NSString stringWithFormat:@"\tHidden File: %@",_url]];
                    
                    [self fileAnalyzer:[NSString stringWithFormat:@"%@/%@",[file stringByDeletingLastPathComponent],_url] :[_url lastPathComponent] :_level+1];
                    
                    //[self fileAnalyzer:[NSString stringWithFormat:@"%@/javascript/%@",[file stringByDeletingLastPathComponent],_url] :[_url lastPathComponent] :_level+1];
                }
            }
        }
    }
}

-(NSString*)pathTagCleanup:(NSString*)path
{
    path = [path stringByReplacingOccurrencesOfString:@"]" withString:@""];
    path = [path stringByReplacingOccurrencesOfString:@"[" withString:@""];
    path = [path stringByReplacingOccurrencesOfString:@"{" withString:@""];
    path = [path stringByReplacingOccurrencesOfString:@"}" withString:@""];
    path = [path stringByReplacingOccurrencesOfString:@":" withString:@""];
    path = [path stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    path = [path stringByReplacingOccurrencesOfString:@"'" withString:@""];
    return path;
}

-(NSString*)pathFromURL:(NSString*)url
{
    url = [url stringByReplacingOccurrencesOfString:@"http://" withString:@""];
    NSArray* domainRoot = [url componentsSeparatedByString: @"/"]; //[url pathComponents];
    long end = [domainRoot count];
    
    if([binExtentions containsObject:[url pathExtension]] || [txtExtentions containsObject:[url pathExtension]] || [url rangeOfString:@"?"].location != NSNotFound)
    {
        end = [domainRoot count] - 1;
    }
    
    NSString* buildURL = @"";
    for(int i = 1; i < end; i++)
    {
        buildURL = [NSString stringWithFormat:@"%@%@/",buildURL,[domainRoot objectAtIndex:i]];
    }
    return buildURL;
}

- (IBAction)tooltip_Click:(NSButton*)button
{
    ToolTipController* tipController = [[ToolTipController alloc] init];
    BOOL show = TRUE;
    
    if([[button title] isEqualToString:@"site"])
    {
        tipController.tip = @"Wix.com website,\nexample: http://bob51.wix.com/test";
    }
    else if([[button title] isEqualToString:@"domain"])
    {
        tipController.tip = @"Your own domain with full path,\nexample: www.coolbeans.com/joe";
    }
    else if([[button title] isEqualToString:@"level"])
    {
        tipController.tip = @"How deep '.js' files will be analyzed.\n\nWARNING: greater than 1 will retreive entire wix skin template.";
    }
    else if([[button title] isEqualToString:@"Download Media"])
    {
        if ([media state] == NSOnState)
        {
            tipController.tip = @"WARNING: all image files will be downloaded, this may be big";
        }
        else
        {
            show = FALSE;
        }
    }
    else if([[button title] isEqualToString:@"Download Editor"])
    {
        if ([editor state] == NSOnState)
        {
            tipController.tip = @"EXPERIMENTAL: Will download wix editor ajax files.";
        }
        else
        {
            show = FALSE;
        }
    }
    else if([[button title] isEqualToString:@"My Server has PHP"])
    {
        if ([php state] == NSOnState)
        {
            tipController.tip = @"EXPERIMENTAL: Emulate dynamic image size with php";
        }
        else
        {
            show = FALSE;
        }
    }
    
    if(show)
    {
        NSPopover* help = [[NSPopover alloc] init];
        help.contentViewController = tipController;
        help.appearance = NSPopoverAppearanceHUD;
        [help setAnimates:YES];
        help.behavior = NSPopoverBehaviorTransient;
        
        
        if (!help.isShown)
        {
            [help showRelativeToRect:[button bounds] ofView:button preferredEdge:NSMaxYEdge];
        }
        else
        {
            [help close];
        }
    }
}

- (IBAction)download_Click:(id)sender;
{
    if([thread isExecuting])
    {
        [thread cancel];
        [self Debug:@"Downloading Stopped"];
        [download setTitle:@"Download"];
        
        [loading stopAnimation: self];
        [loading setHidden:TRUE];
        [progress stopAnimation: self];
    }
    else
    {
        //[site setStringValue:@"http://www.wix.com/website-template/view/html/853"];
        
        [loading setHidden:FALSE];
        [loading startAnimation: self];
        
        [progress setDoubleValue:0];
        [progress startAnimation: self];
        
        //Keeps track of redundant downloads, optimizes bandwidth
        Bandwidth = [[NSMutableSet alloc] init];
        
        if ([[site stringValue] rangeOfString:@"http://"].location == NSNotFound)
        {
            [site setStringValue:[NSString stringWithFormat:@"http://%@",[site stringValue]]];
        }
        
        if ([[domain stringValue] rangeOfString:@"http://"].location == NSNotFound)
        {
            [domain setStringValue:[NSString stringWithFormat:@"http://%@",[domain stringValue]]];
        }
        
        if ([[domain stringValue] rangeOfString:@"127.0.0.1"].location != NSNotFound && [[[domain stringValue] stringByReplacingOccurrencesOfString:@"http://" withString:@""] rangeOfString:@":"].location == NSNotFound)
        {
            [domain setStringValue:[NSString stringWithFormat:@"%@:8000",[domain stringValue]]];
            [php setState:FALSE];
        }
        
        thread = [[NSThread alloc] initWithTarget:self selector:@selector(startThread) object:nil];
        [thread start];
        
        [self Debug:@"Downloading Started"];
        [download setTitle:@"Stop"];
    }
}

- (void)Debug:(NSString*)d
{
    //NSLog(@"%@",d);
    printf("%s\n",[d UTF8String]);
    
    NSString* logpath = [NSString stringWithFormat:@"%@/pwned.log",DownloadPath];
    NSFileHandle* fh = [NSFileHandle fileHandleForWritingAtPath:logpath];
    
    if (!fh)
    {
        [[NSFileManager defaultManager] createFileAtPath:logpath contents:nil attributes:nil];
        fh = [NSFileHandle fileHandleForWritingAtPath:logpath];
    }
    if ( !fh ) return;
    
    @try
    {
        [fh seekToEndOfFile];
        [fh writeData:[[NSString stringWithFormat:@"%@\n",d] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    @catch (NSException * e)
    {
    }
    [fh closeFile];
}
@end
