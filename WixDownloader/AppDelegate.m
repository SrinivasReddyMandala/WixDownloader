#import "AppDelegate.h"
//#include <stdlib.h>

@implementation AppDelegate
NSThread *thread;

- (void)subWindowClosed:(NSNotification *)notification
{
    [NSApp terminate:self];
}

-(NSString*)downloadFile:(NSString*)url
{
    //[self Debug:[NSString stringWithFormat:@"Downloading URL: %@", url]];
    
    NSHTTPURLResponse *urlResponse = nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    
    [request setHTTPMethod:@"GET"];
    [request addValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:25.0) Gecko/20100101 Firefox/25.0" forHTTPHeaderField: @"User-Agent"];
    
    NSData *indexData = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:nil];
    
    if ([urlResponse statusCode] == 200)
    {
        return [[NSString alloc] initWithData:indexData encoding:NSUTF8StringEncoding];
    }
    else
    {
        return NULL;
    }
}

-(void)startThread
{
    NSError * error = nil;
    
    NSString *indexHTML = [self downloadFile:[site stringValue]];
    
    NSString* DownloadPath = [NSString stringWithFormat:@"%@/Downloads/%@",NSHomeDirectory(),[[domain stringValue] stringByReplacingOccurrencesOfString:@"http://" withString:@""]];
    
    //Prevent : in the directory name as port#
    DownloadPath = [DownloadPath stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    
    //Save original
    [indexHTML writeToFile:[NSString stringWithFormat:@"%@/wix.html",DownloadPath] atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    //Create media storage
    if ([media state] == NSOnState)
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/media",DownloadPath] withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    NSArray *jsonHTTP = [indexHTML componentsSeparatedByString: @"\""];
    
    [progress setMaxValue:[jsonHTTP count]];
    
    for(int i = 0; i < [jsonHTTP count]; i++)
    {
        if ([[jsonHTTP objectAtIndex:i] rangeOfString:@"http://"].location != NSNotFound)
        {
            //NSArray *http = [[jsonHTTP objectAtIndex:i] componentsSeparatedByString: @"\""];
            //for(int h = 0; h < [http count]; h++){
            if([[NSThread currentThread] isCancelled])
                [NSThread exit];
            
            //if ([[http objectAtIndex:h] rangeOfString:@"http://"].location != NSNotFound){
            //NSLog(@"> %@", [http objectAtIndex:h]);
            
            //===================================
            NSString* dirRoot= [[NSString alloc] init];
            NSArray* domainRoot = [[[jsonHTTP objectAtIndex:i] stringByReplacingOccurrencesOfString:@"http://" withString:@""] componentsSeparatedByString: @"/"];
            
            for(int d = 1; d < [domainRoot count] -1; d++)
            {
                dirRoot = [dirRoot stringByAppendingString:[NSString stringWithFormat:@"%@/",[domainRoot objectAtIndex:d]]];
            }
            dirRoot = [dirRoot stringByReplacingOccurrencesOfString:@"\"" withString:@""];
            dirRoot = [dirRoot stringByReplacingOccurrencesOfString:@"]" withString:@""];
            dirRoot = [dirRoot stringByReplacingOccurrencesOfString:@"}" withString:@""];
            [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/%@",DownloadPath,dirRoot] withIntermediateDirectories:YES attributes:nil error:&error];
            
            NSString* fileRoot = [domainRoot objectAtIndex:[domainRoot count]-1];
            
            //Get rid of ? in the filename. This is ussually means the the file at the server is dynamic. like a PHP script but we don't care, we need static
            if ([fileRoot rangeOfString:@"?"].location != NSNotFound)
            {
                NSArray* staticFile = [fileRoot componentsSeparatedByString: @"?"];
                fileRoot = [staticFile objectAtIndex:0];
            }
            //===================================
            
            NSData* webBinary;
            
            if([[fileRoot pathExtension] isEqualToString:@"ico"] || [[fileRoot pathExtension] isEqualToString:@"jpg"]) //binary files, no analisys needed
            {
                webBinary = [NSData dataWithContentsOfURL:[NSURL URLWithString:[jsonHTTP objectAtIndex:i]]];
                
                //[self Debug:[NSString stringWithFormat:@"Downloading Binary: %@", fileRoot]];
                
                if ([webBinary writeToFile:[NSString stringWithFormat:@"%@/%@/%@",DownloadPath,dirRoot,fileRoot] atomically:YES])
                {
                    
                }
            }
            else
            {
                NSString* webfile = [self downloadFile:[jsonHTTP objectAtIndex:i]];
                if(webfile != NULL)
                {
                    if ([media state] == NSOnState)
                    {
                        NSArray *uri = [webfile componentsSeparatedByString: @","];
                        for(int u = 0; u < [uri count]; u++)
                        {
                            if ([[uri objectAtIndex:u] rangeOfString:@"\"uri\":"].location != NSNotFound)
                            {
                                NSString* img = [[uri objectAtIndex:u] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
                                img = [img stringByReplacingOccurrencesOfString:@"uri:" withString:@""];
                                
                                webBinary = [NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://static.wixstatic.com/media/%@",img]]];
                                
                                //[self Debug:[NSString stringWithFormat:@"Downloading Media: %@", img]];
                                
                                if ([webBinary writeToFile:[NSString stringWithFormat:@"%@/media/%@",DownloadPath,img] atomically:YES])
                                {
                                    //TODO: wix has a dynamic image by size retreival, make php to emulate the same
                                    if ([php state] == NSOnState)
                                    {
                                        
                                    }
                                }
                            }
                        }
                    }
                    
                    [webfile writeToFile:[NSString stringWithFormat:@"%@/%@/%@",DownloadPath,dirRoot,fileRoot] atomically:YES encoding:NSUTF8StringEncoding error:nil];
                }
            }
            
            BOOL replace = YES;
            if ([[jsonHTTP objectAtIndex:i-2] rangeOfString:@"emailServer"].location != NSNotFound)
            {
                replace = NO;
            }
            
            if ([php state] == NSOnState)  //TODO: create emulating email php?
            {
                NSString* invokePHP = @"<?php\
                if (isset ($_POST['name'])){\
                $to      = $_POST['email'];\
                $subject = $_POST['subject'];\
                $message = $_POST['message'];\
                $headers = \"From: \" . $_POST['name'] . \" <\". $_POST['email'] . \">\";\
                mail($to, $subject, $message, $headers);\
                echo '{\"response\":\"success\"}';\
                }else{\
                echo '{\"response\":\"error\"}';\
                }\
                ?>";
                [invokePHP writeToFile:[NSString stringWithFormat:@"%@/common-services/notification/invoke",DownloadPath] atomically:YES encoding:NSUTF8StringEncoding error:nil];
            }
            
            if ([media state] != NSOnState)
            {
                if ([[jsonHTTP objectAtIndex:i-2] rangeOfString:@"staticMediaUrl"].location != NSNotFound ||
                    [[jsonHTTP objectAtIndex:i-2] rangeOfString:@"staticAudioUrl"].location != NSNotFound)
                {
                    //NSLog(@">> %@",[jsonHTTP objectAtIndex:i-1]);
                    replace = NO;
                }
            }
            
            if(replace == YES)
            {
                indexHTML = [indexHTML stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"http://%@/%@%@",[domainRoot objectAtIndex:0],dirRoot,[domainRoot objectAtIndex:[domainRoot count]-1]] withString:[NSString stringWithFormat:@"%@/%@%@",[domain stringValue],dirRoot,fileRoot]];
            }
            
            //break;
            //}
            //}
        }
        
        float p = i / [jsonHTTP count] * 100;
        //NSLog(@"Complete %ld %% (%d of %ld)", i/[jsonHTTP count], i,[jsonHTTP count]);
        
        [percent setStringValue:[NSString stringWithFormat:@"%.1f %%", p]];
        [progress setDoubleValue:i];
    }
    
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
    
    [self Debug:@"Downloading Finished"];
    [download setTitle:@"Download"];
    [loading stopAnimation: self];
    [loading setHidden:TRUE];
    [progress stopAnimation: self];
    
    if ([[domain stringValue] rangeOfString:@"127.0.0.1"].location != NSNotFound)
    {
        @try
        {
            NSTask* HTTPServer = [[NSTask alloc] init];
            [HTTPServer setLaunchPath:@"/usr/bin/python"];
            [HTTPServer setArguments:@[@"-m", @"SimpleHTTPServer"]];
            [HTTPServer setCurrentDirectoryPath:DownloadPath];
            [HTTPServer launch];
            //[HTTPServer waitUntilExit];
            
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[[domain stringValue] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
            
        }
        @catch (NSException *exception)
        {
            NSLog(@"HTTPServer Error: %@", exception);
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
        [loading setHidden:FALSE];
        [loading startAnimation: self];
        
        [progress setDoubleValue:0];
        [progress startAnimation: self];
        
        /*
         if ([[site stringValue] rangeOfString:@"wix.com"].location == NSNotFound)
         {
         [site setStringValue:[NSString stringWithFormat:@"%@.wix.com",[site stringValue]]];
         }*/
        
        if ([[site stringValue] rangeOfString:@"http://"].location == NSNotFound)
        {
            [site setStringValue:[NSString stringWithFormat:@"http://%@",[site stringValue]]];
        }
        
        if ([[domain stringValue] rangeOfString:@"http://"].location == NSNotFound)
        {
            [domain setStringValue:[NSString stringWithFormat:@"http://%@",[domain stringValue]]];
        }
        
        if ([[domain stringValue] rangeOfString:@"127.0.0.1"].location != NSNotFound)
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
    //[log setStringValue:[[log stringValue] stringByAppendingString:[NSString stringWithFormat:@"%@\n",d]]];
    NSLog(@"%@",d);
}
@end
