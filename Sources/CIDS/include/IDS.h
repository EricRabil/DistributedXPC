//
//  PrivateHeaders.h
//  IDSSwitchblade
//
//  Created by Eric Rabil on 11/30/22.
//

#ifndef PrivateHeaders_h
#define PrivateHeaders_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// MARK: IDSFoundation

typedef NS_OPTIONS(int32_t, IDSListenerCap) {
    iota,
    kIDSListenerCapConsumesLaunchOnDemandIncomingMessages NS_SWIFT_NAME(consumesLaunchOnDemandIncomingMessages),
    kIDSListenerCapConsumesLaunchOnDemandOutgoingMessageUpdates NS_SWIFT_NAME(consumesLaunchOnDemandOutgoingMessageUpdates),
    kIDSListenerCapConsumesLaunchOnDemandSessionMessages NS_SWIFT_NAME(consumesLaunchOnDemandSessionMessages),
    kIDSListenerCapConsumesLaunchOnDemandIncomingData NS_SWIFT_NAME(consumesLaunchOnDemandIncomingData),
    kIDSListenerCapConsumesLaunchOnDemandIncomingProtobuf NS_SWIFT_NAME(consumesLaunchOnDemandIncomingProtobuf),
    kIDSListenerCapConsumesLaunchOnDemandInvitationUpdates NS_SWIFT_NAME(consumesLaunchOnDemandInvitationUpdates),
    kIDSListenerCapConsumesLaunchOnDemandIncomingResource NS_SWIFT_NAME(consumesLaunchOnDemandIncomingResource),
    kIDSListenerCapConsumesLaunchOnDemandEngram NS_SWIFT_NAME(consumesLaunchOnDemandEngram),
    kIDSListenerCapConsumesLaunchOnDemandNetworkAvailableHint NS_SWIFT_NAME(consumesLaunchOnDemandNetworkAvailableHint),
    kIDSListenerCapConsumesLaunchOnDemandAccessoryReportMessages NS_SWIFT_NAME(consumesLaunchOnDemandAccessoryReportMessages),
    kIDSListenerCapConsumesLaunchOnDemandGroupSessionParticipantUpdates NS_SWIFT_NAME(consumesLaunchOnDemandGroupSessionParticipantUpdates),
    kIDSListenerCapConsumesLaunchOnDemandPendingMessageUpdates NS_SWIFT_NAME(consumesLaunchOnDemandPendingMessageUpdates)
};

@class IDSHandle, IDSURI, IDSDestination;

@interface IDSURI: NSObject
-(instancetype)initWithPrefixedURI:(NSString*)uri;
-(instancetype)initWithUnprefixedURI:(NSString*)uri;
-(NSString*)unprefixedURI;
-(int)IDSIDType;
-(int)FZIDType;
-(BOOL)isTokenURI;
-(NSString*)prefixedURI;
@end

@interface IDSHandle: NSObject
-(instancetype)initWithURI:(IDSURI*)uri isUserVisible:(BOOL)visible validationStatus:(int)status;
-(IDSURI*)URI;
-(BOOL)isUserVisible;
-(int)validationStatus;
@end

@interface IDSDestination: NSObject
-(NSSet<IDSURI*>*)normalizedURIs;
-(NSSet<NSString*>*)normalizedURIStrings;
-(NSSet<IDSURI*>*)destinationURIs;
-(BOOL)isGuest;
-(BOOL)isDevice;
-(BOOL)isEmpty;

+(instancetype)destinationWithAlias:(NSString*)alias pushToken:(NSString*)pushToken;
+(instancetype)destinationWithDestinations:(NSArray<IDSDestination*>*)destinations;
+(instancetype)destinationWithString:(NSString*)destination;
+(instancetype)destinationWithURI:(NSString*)uri;
+(instancetype)destinationWithStrings:(NSArray<NSString*>*)strings;
@end

@interface IDSMessageContext: NSObject
-(instancetype)initWithDictionary:(NSDictionary*)dictionary boostContext:(id)boostContext;
NS_ASSUME_NONNULL_END
-(NSString*) outgoingResponseIdentifier;
-(NSString*) incomingResponseIdentifier;
-(NSString*) serviceIdentifier;
-(NSString*) fromID;
-(NSString*) originalGUID;
-(NSString*) toID;
-(NSString*) originalDestinationDevice;
-(NSData*) engramGroupID;
-(NSNumber*) originalCommand;
-(NSNumber*) serverTimestamp;
-(BOOL) expectsPeerResponse;
-(BOOL) wantsManualAck;
-(BOOL) fromServerStorage;
-(NSDate*) serverReceivedTime;
-(NSTimeInterval) averageLocalRTT;
-(BOOL) deviceBlackedOut;
-(NSError*) wpConnectionError;
-(NSString*) senderCorrelationIdentifier;
NS_ASSUME_NONNULL_BEGIN
@end

@interface IDSProtobuf: NSObject
-(instancetype)initWithProtobufData:(NSData*)data type:(uint16_t)type isResponse:(BOOL)isResponse;
@end

// MARK: IDS

@class IDSDevice, IDSService, IDSAccount, IDSAccountController, IDSConnection, IDSSession;

typedef id IDSUnhandledProtobuf;
typedef id IDSOpportunisticData;
typedef id IDSResourceMetadata;
typedef int32_t IDSPendingMessage;

#define IDSWeak __attribute__((weak_import))

IDSWeak @interface IDSInternalQueueController: NSObject
+(instancetype)sharedInstance;
-(void)performBlock:(void(^)(void))block;
-(void)performBlock:(void(^)(void))block waitUntilDone:(BOOL)wait;
-(void)assertQueueIsCurrent;
-(void)assertQueueIsNotCurrent;
@end

// Dear future Eric, please, try your best to not work with the daemon directly. Use the higher-level APIs afforded to you by IDS.

//@protocol IDSDaemonListenerProtocol
//@optional
//-(void)messageReceived:(NSDictionary*)message withGUID:(NSString*)guid withPayload:(NSDictionary*)payload forTopic:(NSString*)topic toIdentifier:(NSString*)identifier fromID:(NSString*)from context:(NSDictionary*)context;
//@end
//
//@interface IDSDaemonListener: NSObject
//-(void)addHandler:(id<IDSDaemonListenerProtocol>)handler;
//@end
//
@interface IDSDaemonController: NSObject
+(instancetype)sharedInstance;
//-(NSString*)listenerID;
//-(IDSDaemonListener*)listener;
//-(void)addListenerID:(NSString*)listenerID services:(NSSet<NSString*>*)services commands:(NSSet<NSNumber*>*)commands;
//-(void)addListenerID:(NSString*)listenerID services:(NSSet<NSString*>*)services;
//-(void)addListenerID:(NSString*)listenerID;
-(void)setCapabilities:(IDSListenerCap)caps forListenerID:(NSString*)listener shouldLog:(BOOL)shouldLog;
-(IDSListenerCap)capabilitiesForListenerID:(NSString*)listenerID;
-(void)setCommands:(NSSet<NSNumber*>*)commands forListenerID:(NSString*)listener;
//-(void)connectToDaemon;
//-(void)registerForNotificationsOnServices:(NSSet<NSString*>*)services;
-(NSSet<NSNumber*>*)commandsForListenerID:(NSString*)listenerID;
@end

@protocol IDSConnectionDelegate
@end

IDSWeak @interface _IDSConnection: NSObject
@end

@interface IDSConnection: NSObject
-(IDSAccount*)account;
-(BOOL)isActive;
-(void)addDelegate:(id<IDSConnectionDelegate>)delegate queue:(dispatch_queue_t)queue;
-(void)removeDelegate:(id<IDSConnectionDelegate>)delegate;
-(void)sendMessage:(id)message toDestinations:(NSArray<IDSDestination*>*)destinations priority:(int)priority options:(NSDictionary*)options identifier:(NSString*)identifier error:(NSError** _Nullable)error;
-(_IDSConnection* _Nullable)_internal;
@end

@interface IDSDevice: NSObject
-(NSString*)uniqueID;
-(NSString*)name;
-(NSString*)service;
-(BOOL)isNearby;
-(BOOL)isConnected;
-(BOOL)isCloudConnected;
-(BOOL)locallyPresent;
-(IDSDestination*)destination;
@end

@protocol IDSServiceDelegate
@optional
-(void)service:(IDSService*)service account:(IDSAccount*)account incomingOpportunisticData:(IDSOpportunisticData)data withIdentifier:(NSString*)identifier fromID:(NSString*)id context:(IDSMessageContext*)context;
-(void)service:(IDSService*)service account:(IDSAccount*)account incomingMessage:(NSDictionary*)message fromID:(NSString*)id context:(IDSMessageContext*)context;
-(void)service:(IDSService*)service account:(IDSAccount*)account incomingData:(NSData*)data fromID:(NSString*)id context:(IDSMessageContext*)context;
-(void)service:(IDSService*)service account:(IDSAccount*)account incomingUnhandledProtobuf:(IDSProtobuf*)protobuf fromID:(NSString*)id context:(IDSMessageContext*)context;
-(void)service:(IDSService*)service account:(IDSAccount*)account incomingResourceAtURL:(NSURL*)url fromID:(NSString*)id context:(IDSMessageContext*)context;
-(void)service:(IDSService*)service account:(IDSAccount*)account incomingResourceAtURL:(NSURL*)url metadata:(IDSResourceMetadata)metadata fromID:(NSString*)id context:(IDSMessageContext*)context;
-(void)service:(IDSService*)service account:(IDSAccount*)account incomingPendingMessageOfType:(IDSPendingMessage)type fromID:(NSString*)id context:(IDSMessageContext*)context;
-(void)service:(IDSService*)service account:(IDSAccount*)account identifier:(NSString*)identifier didSendWithSuccess:(BOOL)success error:(NSError* _Nullable)error;
-(void)service:(IDSService*)service account:(IDSAccount*)account identifier:(NSString*)identifier didSendWithSuccess:(BOOL)success error:(NSError* _Nullable)error context:(IDSMessageContext*)context;
-(void)service:(IDSService*)service account:(IDSAccount*)account identifier:(NSString*)identifier sentBytes:(int)sentBytes totalBytes:(int)totalBytes;
-(void)service:(IDSService*)service account:(IDSAccount*)account identifier:(NSString*)identifier hasBeenDeliveredWithContext:(IDSMessageContext*)context;
-(void)service:(IDSService*)service account:(IDSAccount*)account identifier:(NSString*)identifier fromID:(NSString*)id hasBeenDeliveredWithContext:(IDSMessageContext*)context;
-(void)service:(IDSService*)service account:(IDSAccount*)account inviteReceivedForSession:(IDSSession*)session fromID:(NSString*)id;
-(void)service:(IDSService*)service account:(IDSAccount*)account inviteReceivedForSession:(IDSSession*)session fromID:(NSString*)id withOptions:(id)options;
-(void)service:(IDSService*)service account:(IDSAccount*)account inviteReceivedForSession:(IDSSession*)session fromID:(NSString*)id withContext:(IDSMessageContext*)context;
-(void)service:(IDSService*)service account:(IDSAccount*)account receivedGroupSessionParticipantUpdate:(id)update;
-(void)service:(IDSService*)service account:(IDSAccount*)account receivedGroupSessionParticipantUpdate:(id)update context:(IDSMessageContext*)context;
-(void)service:(IDSService*)service account:(IDSAccount*)account receivedGroupSessionParticipantDataUpdate:(id)update;
-(void)service:(IDSService*)service didSendOpportunisticDataWithIdentifier:(NSString*)identifier toIDs:(id)ids;
-(void)service:(IDSService*)service activeAccountsChanged:(NSArray<IDSAccount*>*)activeAccounts;
-(void)service:(IDSService*)service devicesChanged:(NSArray<IDSDevice*>*)devices;
-(void)service:(IDSService*)service nearbyDevicesChanged:(NSArray<IDSDevice*>*)devices;
-(void)service:(IDSService*)service connectedDevicesChanged:(NSArray<IDSDevice*>*)devices;
-(void)service:(IDSService*)service linkedDevicesChanged:(NSArray<IDSDevice*>*)devices;
//-(void)service:didSwitchActivePairedDevice:acknowledgementBlock:
-(void)serviceSpaceDidBecomeAvailable:(id)space;
-(void)serviceAllowedTrafficClassifiersDidReset:(id)didReset;
@end

@interface NSString ()
+ (NSString*) copyStringGUIDForObject:(id)arg1;
@end

IDSWeak @interface _IDSAccount: NSObject
-(NSString*)uniqueID;
@end

IDSWeak @interface _IDSService: NSObject
-(id _Nullable)_setupNewConnectionForAccount:(_IDSAccount*)account;
@end

@interface IDSService: NSObject
-(instancetype)initWithService:(NSString*)service;
-(instancetype)initWithService:(NSString*)service commands:(NSSet<NSNumber*>*)commands;
-(BOOL)iCloudAccount;
-(id)serviceDomain;
-(NSSet<IDSAccount*>*)accounts;
-(NSSet<IDSDevice*>*)devices;
-(NSString*)serviceIdentifier;
-(BOOL)canSend;
-(IDSDevice* _Nullable)deviceForFromID:(NSString*)fromID;
-(NSSet<NSString*>*)aliases;
-(NSSet<NSString*>*)activeAliases;
-(void)addDelegate:(id<IDSServiceDelegate>)delegate queue:(dispatch_queue_t)queue;
-(_IDSService* _Nullable)_internal;

-(void)sendProtobuf:(IDSProtobuf*)protobuf
        fromAccount:(IDSAccount*)account
     toDestinations:(NSArray<IDSDestination*>*)destinations
           priority:(int)priority
            options:(NSDictionary*)options
         identifier:(NSString* _Nullable* _Nullable)identifier
              error:(NSError* _Nullable* _Nullable)error;

-(void)sendMessage:(NSDictionary*)message
       fromAccount:(IDSAccount*)account
    toDestinations:(NSArray<IDSDestination*>*)destinations
          priority:(int)priority
           options:(NSDictionary*)options
        identifier:(NSString* _Nullable* _Nullable)identifier
             error:(NSError* _Nullable* _Nullable)error;

-(void)sendData:(NSData*)message
    fromAccount:(IDSAccount*)account
 toDestinations:(NSArray<IDSDestination*>*)destinations
       priority:(int)priority
        options:(NSDictionary*)options
     identifier:(NSString* _Nullable* _Nullable)identifier
          error:(NSError* _Nullable* _Nullable)error;

-(void)sendResourceAtURL:(NSURL*)message
                metadata:(NSDictionary*)metadata
          toDestinations:(NSArray<IDSDestination*>*)destinations
                priority:(int)priority
                 options:(NSDictionary*)options
              identifier:(NSString* _Nullable* _Nullable)identifier
                   error:(NSError* _Nullable* _Nullable)error;

-(void)sendAckForMessageWithContext:(IDSMessageContext*)context;
-(int)maxEffectivePayloadSize;
@end

@protocol IDSAccountDelegate
@optional
-(void)account:(IDSAccount*)account isActiveChanged:(BOOL)active;
-(void)account:(IDSAccount*)account devicesChanged:(NSArray<IDSDevice*>*)devices;
-(void)account:(IDSAccount*)account nearbyDevicesChanged:(NSArray<IDSDevice*>*)devices;
-(void)account:(IDSAccount*)account connectedDevicesChanged:(NSArray<IDSDevice*>*)devices;
@end

@interface IDSAccount: NSObject
-(NSString*)uniqueID;
-(NSString*)loginID;
-(NSString*)serviceName;
-(NSString*)primaryServiceName;
-(int)accountType;
-(BOOL)isActive;
-(BOOL)isUserDisabled;
-(BOOL)canSend;
-(NSSet<IDSDevice*>*)devices;
-(NSSet<IDSDevice*>*)nearbyDevices;
-(NSSet<IDSHandle*>*)handles;
-(NSArray<NSDictionary*>*)aliases;
-(NSArray<NSString*>*)aliasStrings;
-(NSDictionary*)profileInfo;
-(BOOL)isEnabled;
-(BOOL)isUsableForOuterMessaging;
-(NSDate* _Nullable)dateRegistered;
-(NSArray*)registeredURIs;
-(NSArray<IDSURI*>*)accountRegisteredURIs;
-(NSString* _Nullable)pushToken;
-(NSString*)profileID;
-(NSString*)regionID;
-(NSString* _Nullable)regionBasePhoneNumber;
-(NSString*)displayName;
-(NSString*)userUniqueIdentifier;
-(void)authenticateAccount;
-(void)validateProfile;
-(void)registerAccount;
-(void)unregisterAccount;
-(void)forceRemoveAccount;
-(void)deactivateAndPurgeIdentify;
-(void)addDelegate:(id<IDSAccountDelegate>)delegate queue:(dispatch_queue_t)queue;
-(_IDSAccount* _Nullable)_internal;
@end

@protocol IDSAccountControllerDelegate
@optional
-(void)accountController:(IDSAccountController*)controller accountRemoved:(IDSAccount*)account;
-(void)accountController:(IDSAccountController*)controller accountAdded:(IDSAccount*)account;
-(void)accountController:(IDSAccountController*)controller accountUpdated:(IDSAccount*)account;
-(void)accountController:(IDSAccountController*)controller accountEnabled:(IDSAccount*)account;
-(void)accountController:(IDSAccountController*)controller accountDisabled:(IDSAccount*)account;
@end

@interface IDSAccountController: NSObject
-(instancetype)initWithService:(NSString*)service;
-(NSSet<IDSAccount*>*)accounts;
-(NSSet<IDSAccount*>*)enabledAccounts;
-(NSString*)serviceName;
-(void)addDelegate:(id<IDSAccountControllerDelegate>)delegate queue:(dispatch_queue_t)queue;
@end

@protocol IDSSessionDelegate

@end

IDSWeak @interface _IDSSession: NSObject

@end

@interface IDSSession: NSObject
-(instancetype)initWithAccount:(IDSAccount*)account destinations:(NSSet<IDSDestination*>*)destinations options:(NSDictionary*)options;
-(instancetype)initWithAccount:(IDSAccount*)account destinations:(NSSet<IDSDestination*>*)destinations transportType:(int)type;
-(void)setDelegate:(id<IDSSessionDelegate>)delegate queue:(dispatch_queue_t)queue;
-(NSString*)uniqueID;
-(void)sendInvitation;
-(void)sendAllocationRequest:(NSDictionary*)options;
-(void)sendInvitationWithData:(NSData*)data;
-(_IDSSession* _Nullable)_internal;
@end

NS_ASSUME_NONNULL_END

#endif /* PrivateHeaders_h */
