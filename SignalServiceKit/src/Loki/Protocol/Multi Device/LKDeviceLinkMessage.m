#import "LKDeviceLinkMessage.h"
#import "OWSIdentityManager.h"
#import "OWSPrimaryStorage+Loki.h"
#import "ProfileManagerProtocol.h"
#import "ProtoUtils.h"
#import "SSKEnvironment.h"
#import "SignalRecipient.h"
#import <SignalCoreKit/NSData+OWS.h>
#import <SignalCoreKit/NSDate+OWS.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

@implementation LKDeviceLinkMessage

#pragma mark Convenience
- (LKDeviceLinkMessageKind)kind {
    if (self.masterSignature != nil) {
        return LKDeviceLinkMessageKindAuthorization;
    } else {
        return LKDeviceLinkMessageKindRequest;
    }
}

#pragma mark Initialization
- (instancetype)initInThread:(TSThread *)thread masterHexEncodedPublicKey:(NSString *)masterHexEncodedPublicKey slaveHexEncodedPublicKey:(NSString *)slaveHexEncodedPublicKey masterSignature:(NSData * _Nullable)masterSignature slaveSignature:(NSData *)slaveSignature {
    self = [self initOutgoingMessageWithTimestamp:NSDate.ows_millisecondTimeStamp inThread:thread messageBody:@"" attachmentIds:[NSMutableArray<NSString *> new]
        expiresInSeconds:0 expireStartedAt:0 isVoiceMessage:NO groupMetaMessage:TSGroupMetaMessageUnspecified quotedMessage:nil contactShare:nil linkPreview:nil];
    if (self) {
        _masterHexEncodedPublicKey = masterHexEncodedPublicKey;
        _slaveHexEncodedPublicKey = slaveHexEncodedPublicKey;
        _masterSignature = masterSignature;
        _slaveSignature = slaveSignature;
    }
    return self;
}

#pragma mark Building
- (SSKProtoContentBuilder *)prepareCustomContentBuilder:(SignalRecipient *)recipient {
    SSKProtoContentBuilder *contentBuilder = SSKProtoContent.builder;
    NSError *error;
    if (self.kind == LKDeviceLinkMessageKindRequest) {
        // The slave device attaches a pre key bundle with the request it sends, so that a
        // session can be established with the master device.
        PreKeyBundle *preKeyBundle = [OWSPrimaryStorage.sharedManager generatePreKeyBundleForContact:recipient.recipientId];
        SSKProtoPrekeyBundleMessageBuilder *preKeyBundleMessageBuilder = [SSKProtoPrekeyBundleMessage builderFromPreKeyBundle:preKeyBundle];
        SSKProtoPrekeyBundleMessage *preKeyBundleMessage = [preKeyBundleMessageBuilder buildAndReturnError:&error];
        if (error || preKeyBundleMessage == nil) {
            OWSFailDebug(@"Failed to build pre key bundle message for: %@ due to error: %@.", recipient.recipientId, error);
            return nil;
        } else {
            [contentBuilder setPrekeyBundleMessage:preKeyBundleMessage];
        }
    } else {
        // The master device attaches its display name and profile picture URL to the device link
        // authorization message, so that the slave device is in sync with these things as soon
        // as possible.
        id<ProfileManagerProtocol> profileManager = SSKEnvironment.shared.profileManager;
        NSString *displayName = profileManager.localProfileName;
        NSString *profilePictureURL = profileManager.profilePictureURL;
        SSKProtoDataMessageLokiProfileBuilder *profileBuilder = [SSKProtoDataMessageLokiProfile builder];
        [profileBuilder setDisplayName:displayName];
        [profileBuilder setProfilePicture:profilePictureURL ?: @""];
        SSKProtoDataMessageBuilder *messageBuilder = [SSKProtoDataMessage builder];
        [messageBuilder setProfile:[profileBuilder buildAndReturnError:nil]];
        [ProtoUtils addLocalProfileKeyToDataMessageBuilder:messageBuilder];
        [contentBuilder setDataMessage:messageBuilder];
    }
    // Build the device link message
    SSKProtoLokiDeviceLinkMessageBuilder *deviceLinkMessageBuilder = [SSKProtoLokiDeviceLinkMessage builder];
    [deviceLinkMessageBuilder setMasterHexEncodedPublicKey:self.masterHexEncodedPublicKey];
    [deviceLinkMessageBuilder setSlaveHexEncodedPublicKey:self.slaveHexEncodedPublicKey];
    if (self.masterSignature != nil) { [deviceLinkMessageBuilder setMasterSignature:self.masterSignature]; }
    [deviceLinkMessageBuilder setSlaveSignature:self.slaveSignature];
    SSKProtoLokiDeviceLinkMessage *deviceLinkMessage = [deviceLinkMessageBuilder buildAndReturnError:&error];
    if (error || deviceLinkMessage == nil) {
        OWSFailDebug(@"Failed to build device link message for: %@ due to error: %@.", recipient.recipientId, error);
        return nil;
    } else {
        [contentBuilder setLokiDeviceLinkMessage:deviceLinkMessage];
    }
    // Return
    return contentBuilder;
}

#pragma mark Settings
- (uint)ttl { return (uint)[LKTTLUtilities getTTLFor:LKMessageTypeLinkDevice]; }
- (BOOL)shouldSyncTranscript { return NO; }
- (BOOL)shouldBeSaved { return NO; }

@end
