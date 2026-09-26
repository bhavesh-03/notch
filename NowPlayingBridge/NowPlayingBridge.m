//
//  NowPlayingBridge.m
//  NowPlayingBridge
//
//  Loaded into /usr/bin/perl by the Notch app. Apple's now-playing daemon only answers
//  Apple-signed processes, and perl is one, so this code runs inside it.
//
//  Protocol (one line per message):
//    stdout: a JSON object whenever the now-playing state changes; {"active":false} when nothing is playing
//    stdin:  "toggle", "next" or "previous"; end of input (the app quit) ends the process
//

#import <Foundation/Foundation.h>
#import <objc/message.h>
#include <dlfcn.h>

typedef Boolean (*SendCommandFn)(int command, NSDictionary *options);

static const int kCommandTogglePlayPause = 2;
static const int kCommandNextTrack = 4;
static const int kCommandPreviousTrack = 5;

static id Call(id object, const char *selectorName) {
    SEL selector = sel_registerName(selectorName);
    return [object respondsToSelector:selector] ? ((id (*)(id, SEL))objc_msgSend)(object, selector) : nil;
}

static BOOL CallBool(id object, const char *selectorName) {
    SEL selector = sel_registerName(selectorName);
    return [object respondsToSelector:selector] ? ((BOOL (*)(id, SEL))objc_msgSend)(object, selector) : NO;
}

static NSDictionary *Snapshot(Class request) {
    NSDictionary *info = Call(Call(request, "localNowPlayingItem"), "nowPlayingInfo");
    if (info.count == 0) return @{ @"active": @NO };

    id client = Call(Call(request, "localNowPlayingPlayerPath"), "client");
    NSString *appBundleID = Call(client, "parentApplicationBundleIdentifier") ?: Call(client, "bundleIdentifier");
    NSDate *timestamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];

    return @{
        @"active": @YES,
        @"isPlaying": @(CallBool(request, "localIsPlaying")),
        @"title": info[@"kMRMediaRemoteNowPlayingInfoTitle"] ?: @"",
        @"artist": info[@"kMRMediaRemoteNowPlayingInfoArtist"] ?: @"",
        @"album": info[@"kMRMediaRemoteNowPlayingInfoAlbum"] ?: @"",
        @"duration": info[@"kMRMediaRemoteNowPlayingInfoDuration"] ?: @0,
        @"elapsedTime": info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"] ?: @0,
        @"playbackRate": info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"] ?: @0,
        @"timestamp": @(timestamp ? timestamp.timeIntervalSince1970 : NSDate.date.timeIntervalSince1970),
        @"appName": Call(client, "displayName") ?: @"",
        @"appBundleIdentifier": appBundleID ?: @"",
    };
}

static void ReadCommands(SendCommandFn send) {
    char line[64];
    while (fgets(line, sizeof line, stdin)) {
        NSString *command = [[NSString stringWithUTF8String:line] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        int code = [command isEqualToString:@"toggle"] ? kCommandTogglePlayPause
                 : [command isEqualToString:@"next"] ? kCommandNextTrack
                 : [command isEqualToString:@"previous"] ? kCommandPreviousTrack
                 : -1;
        if (code >= 0 && send) send(code, nil);
    }
    exit(0);
}

__attribute__((constructor)) static void StartBridge(void) {
    if (!getenv("NOTCH_NOW_PLAYING_BRIDGE")) return;

    void *mediaRemote = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    Class request = NSClassFromString(@"MRNowPlayingRequest");
    SendCommandFn send = mediaRemote ? (SendCommandFn)dlsym(mediaRemote, "MRMediaRemoteSendCommand") : NULL;
    if (!request) {
        printf("{\"error\":\"MRNowPlayingRequest unavailable\"}\n");
        fflush(stdout);
        exit(1);
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ ReadCommands(send); });

    __block NSData *lastLine = nil;
    void (^publish)(void) = ^{
        NSData *line = [NSJSONSerialization dataWithJSONObject:Snapshot(request) options:NSJSONWritingSortedKeys error:nil];
        if (!line || [line isEqualToData:lastLine]) return;
        lastLine = line;
        fwrite(line.bytes, 1, line.length, stdout);
        fputc('\n', stdout);
        fflush(stdout);
    };

    publish();
    [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) { publish(); }];
    [[NSRunLoop mainRunLoop] run];
}
