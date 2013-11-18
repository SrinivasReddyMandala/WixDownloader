#import "AppDelegate.h"

@implementation AppDelegate

NSThread *thread;
NSString* DownloadPath;
NSMutableSet* Bandwidth;
NSArray* http;
NSArray* allowedDomains;
NSArray* binExtentions;
NSArray* txtExtentions;
NSArray* wixTags;
NSArray* wixTagsURL;
NSString* skinURL = @"http://static.parastorage.com/services/skins/2.648.0";
NSString* webURL = @"http://static.parastorage.com/services/web/2.648.0";
NSString* coreURL = @"http://static.parastorage.com/services/core/2.648.0";
NSString* mediaURL = @"http://static.wixstatic.com/media";

- (id) init
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:nil];
    return self;
}

- (void)windowWillClose:(NSNotification *)notification
{
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
    
    if ([url rangeOfString:@"editor"].location != NSNotFound && [editor state] != NSOnState)
    {
        allow = FALSE;
    }
    
    if(allow && ![Bandwidth containsObject:url])
    {
        
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
            [Bandwidth addObject:url];
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
    wixTags = [NSArray arrayWithObjects: @"[tdr]",@"[baseThemeDir]" @"[webThemeDir]", @"[themeDir]", @"[ulc]", @"SKIN_ICON_PATH+", nil];
    wixTagsURL = [NSArray arrayWithObjects: @"/", @"/", @"/", @"/", @"/", @"/", nil];
    
    //TODO: Wireshark these out ...find the URLS
    
    //[tdr],[baseThemeDir]      =   BASE_THEME_DIRECTORY
    //[themeDir]                =   THEME_DIRECTORY
    //[webThemeDir]             =   WEB_THEME_DIRECTORY
    //==================================
    
    http = [NSArray arrayWithObjects: @"http://", @"https://", nil];
    binExtentions = [NSArray arrayWithObjects: @"ico", @"png", @"jpg", @"jpeg", @"gif", @"mp3", @"wix_mp", @"swf", @"html", @"htm", nil]; //wix_mp looks like png format
    txtExtentions = [NSArray arrayWithObjects: @"js", @"json", @"z", @"css", nil];
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
    
    //Get static URLs dynamically
    for(int i = 0; i < [jsonHTTP count]; i++)
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
            
            for(int d = 1; d < [domainRoot count]; d++) //we only need first and last
            {
                dirRoot = [dirRoot stringByAppendingString:[NSString stringWithFormat:@"%@/",[domainRoot objectAtIndex:d]]];
                //=========== index.json ============
                // This is tricky to detect, but wix has many index.json
                // hidden in directories, make sure we don't miss them
                if ([dirRoot rangeOfString:@"?"].location == NSNotFound && [[dirRoot pathExtension] length] < 3)
                {
                    [self fileAnalyzer:[NSString stringWithFormat:@"http://%@/%@index.json",[domainRoot objectAtIndex:0],dirRoot] :@"index.json"];
                }
                //=========== index.json ============
            }
            
            dirRoot = [self pathFromURL:fileDownload];
            
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
                [self fileAnalyzer:fileDownload :fileRoot];
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
    system([[NSString stringWithFormat:@"rm -r %@/wix-html-editor-pages-webapp",DownloadPath] UTF8String]);
    system([[NSString stringWithFormat:@"rm -r %@/wix-public-html-renderer",DownloadPath] UTF8String]);
    
    [self Debug:@"Downloading Finished"];
    [download setTitle:@"Download"];
    [loading stopAnimation: self];
    [loading setHidden:TRUE];
    [progress stopAnimation: self];
    
    
    // TODO: Looks like some "skin" graphics files are hidden deep inside java
    // do a server sweep and look for 404 requests on live Safari view.
    
    if ([[domain stringValue] rangeOfString:@"127.0.0.1:8000"].location != NSNotFound)
    {
        @try
        {
            [self Debug:@"Starting HTTPServer ..."];
            
            NSTask* HTTPServer = [[NSTask alloc] init];
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

-(void)fileAnalyzer:(NSString*)file :(NSString*)fileRoot
{
    //Apple Bug? when doing stringByDeletingLastPathComponent for URL it kicks out one of slash from http://
    file = [self http_correctURL: file];
    
    NSString* webfile = [self downloadFile:file];
    
    [self Debug:[NSString stringWithFormat:@"> File Analyzer: (%ld) %@", [webfile length], file]];
    
    if(webfile != NULL)
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/%@",DownloadPath,[self pathFromURL:file]] withIntermediateDirectories:YES attributes:nil error:nil];
        
        //[self Debug:[NSString stringWithFormat:@"Replace %@ > %@", file,[NSString stringWithFormat:@"%@/%@/%@",[domain stringValue],[self pathFromURL:file],fileRoot]]];
        webfile = [webfile stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\"%@\"",file] withString:[NSString stringWithFormat:@"\"%@/%@/%@\"",[domain stringValue],[self pathFromURL:file],fileRoot]];
        [webfile writeToFile:[NSString stringWithFormat:@"%@/%@/%@",DownloadPath,[self pathFromURL:file],fileRoot] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        NSData* webBinary;
        NSArray *split;
        
        if([[fileRoot pathExtension] isEqualToString:@"js"])
        {
            if ([webfile rangeOfString:@","].location != NSNotFound)
            {
                split = [webfile componentsSeparatedByString: @","];
            }
            else if ([webfile rangeOfString:@";"].location != NSNotFound)
            {
                split = [webfile componentsSeparatedByString: @";"];
            }
            
            NSArray* jsExtentions = [NSArray arrayWithObjects: @"background-image:url",@"background:url",@"iconUrl:", nil];
            
            for(int u = 0; u < [split count]; u++)
            {
                NSString* img = [split objectAtIndex:u];
                
                BOOL link = FALSE;
                for(int i = 0; i < [jsExtentions count]; i++)
                {
                    if ([[split objectAtIndex:u] rangeOfString:[jsExtentions objectAtIndex:i]].location != NSNotFound)
                    {
                        @try
                        {
                            NSArray* bktLeft = [[split objectAtIndex:u] componentsSeparatedByString: @")"];
                            NSArray* bktRight = [[bktLeft objectAtIndex:0] componentsSeparatedByString: @"("];
                            img = [bktRight objectAtIndex:1];
                            link = TRUE;
                            break;
                        }
                        @catch (NSException *exception)
                        {
                            @try
                            {
                                NSArray* tagSplit = [[split objectAtIndex:u] componentsSeparatedByString: @"\""];
                                for(int t = 0; t < [tagSplit count]; t++)
                                {
                                    if ([[tagSplit objectAtIndex:t] rangeOfString:@"/"].location != NSNotFound)
                                    {
                                        img = [tagSplit objectAtIndex:t];
                                        break;
                                    }
                                }
                            }
                            @catch (NSException *exception)
                            {
                                return;
                            }
                        }
                    }
                }
                if (link)
                {
                    img = [self pathTagCleanup:img];
                    
                    [self Debug:[NSString stringWithFormat:@"\tHidden File: %@",img]];
                    //http://localhost/skins/images/wysiwyg/core/themes/base/
                    
                    [[NSFileManager defaultManager] createDirectoryAtPath:[[NSString stringWithFormat:@"%@/%@/%@",DownloadPath,[self pathFromURL:file],img] stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
                    
                    //TODO: Finish this part
                }
            }
        }
        else if([[fileRoot pathExtension] isEqualToString:@"json"] || [[fileRoot pathExtension] isEqualToString:@"z"])
        {
            split = [webfile componentsSeparatedByString: @","];
            NSArray* jsonExtentions = [NSArray arrayWithObjects:@"\"url\":", @"\"uri\":", @"\"componentType\":", nil];
            NSString* img = @"";
            NSString* resources_url = @"";
            
            for(int u = 0; u < [split count]; u++)
            {
                BOOL link = FALSE;
                for(int i = 0; i < [jsonExtentions count]; i++)
                {
                    if ([[split objectAtIndex:u] rangeOfString:@"\"resources\":"].location != NSNotFound)
                    {
                        resources_url = [NSString stringWithFormat:@"%@/",[self pathTagCleanup:img]];
                    }
                    
                    if ([[split objectAtIndex:u] rangeOfString:[jsonExtentions objectAtIndex:i]].location != NSNotFound)
                    {
                        //Ahh this is tricky Ajax stuff ...if there is a { infront it means there is an extra "previous" incapsulation to the url path!
                        if ([[split objectAtIndex:u] rangeOfString:[NSString stringWithFormat:@"{%@",[jsonExtentions objectAtIndex:i]]].location != NSNotFound)
                        {
                            img = [NSString stringWithFormat:@"%@/%@",resources_url,[[split objectAtIndex:u] stringByReplacingOccurrencesOfString:[jsonExtentions objectAtIndex:i] withString:@""]];
                        }
                        else
                        {
                            img = [[split objectAtIndex:u] stringByReplacingOccurrencesOfString:[jsonExtentions objectAtIndex:i] withString:@""];
                        }
                        
                        img = [img stringByReplacingOccurrencesOfString:@"\"resources\":" withString:@""];
                        
                        link = TRUE;
                        break;
                    }
                }
                
                if (link)
                {
                    img = [self pathTagCleanup:img];
                    
                    if ([img rangeOfString:@"/"].location == NSNotFound && [img rangeOfString:@"."].location != NSNotFound && ![[img pathExtension] isEqualToString:@"js"])
                    {
                        // Another tricky Ajax
                        // This is most likely "componentType:" and it is linked to a hidden .js file
                        // We want to avoid downloading everything from "/services/skins" so this is why it is filtered in here.
                        // All references are located in "/services/skins/2.648.0/viewerSkinData.min.js"
                        
                        // Example:
                        // wysiwyg.viewer.skins.VideoSkin > http://static.parastorage.com/services/skins/services/skins/2.648.0/javascript/wysiwyg/viewer/skins/VideoSkin.js
                        // wysiwyg.viewer.components.WPhoto > http://static.parastorage.com/services/web/2.648.0/javascript/wysiwyg/viewer/components/WPhoto.js
                        
                        //TODO: finish this
                        
                        img = [img stringByReplacingOccurrencesOfString:@"." withString:@"/"];
                        
                        [self Debug:[NSString stringWithFormat:@"\tSkin File: %@.js",img]];
                        
                        if ([img rangeOfString:@"skin" options:NSCaseInsensitiveSearch].location != NSNotFound)
                        {
                            [self fileAnalyzer:[NSString stringWithFormat:@"%@/javascript/%@.js",skinURL,img] :[NSString stringWithFormat:@"%@.js",[img lastPathComponent]]];
                        }
                        else if ([img rangeOfString:@"viewer/components"].location != NSNotFound)
                        {
                            [self fileAnalyzer:[NSString stringWithFormat:@"%@/javascript/%@.js",webURL,img] :[NSString stringWithFormat:@"%@.js",[img lastPathComponent]]];
                        }
                        else if ([img rangeOfString:@"core/components"].location != NSNotFound)
                        {
                            img = [img stringByReplacingOccurrencesOfString:@"mobile/" withString:@""]; // ..looks like "mobile" is being ignored in path
                            [self fileAnalyzer:[NSString stringWithFormat:@"%@/javascript/%@.js",coreURL,img] :[NSString stringWithFormat:@"%@.js",[img lastPathComponent]]];
                        }
                    }
                    else
                    {
                        [self Debug:[NSString stringWithFormat:@"\tHidden File: %@",img]];
                        
                        if([binExtentions containsObject:[img pathExtension]] && [media state] == NSOnState) //binary files, no analisys needed
                        {
                            [self Debug:[NSString stringWithFormat:@"\tDownloading Media File: %@", img]];
                            
                            img = [NSString stringWithFormat:@"%@/%@",mediaURL,img];
                            
                            webBinary = [NSData dataWithContentsOfURL:[NSURL URLWithString:img]];
                            
                            [[NSFileManager defaultManager] createDirectoryAtPath:[[NSString stringWithFormat:@"%@/%@",DownloadPath,[self pathFromURL:img]] stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
                            
                            if ([webBinary writeToFile:[NSString stringWithFormat:@"%@/%@/%@",DownloadPath,[self pathFromURL:file],img] atomically:YES])
                            {
                                //TODO: wix has a dynamic image by size, make php to emulate the same
                                if ([php state] == NSOnState)
                                {
                                    
                                }
                            }
                        }
                        else if([txtExtentions containsObject:[img pathExtension]]) //binary files, no analisys needed
                        {
                            [self fileAnalyzer:[NSString stringWithFormat:@"%@/%@",[file stringByDeletingLastPathComponent],img] :[img lastPathComponent]];
                        }
                    }
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
