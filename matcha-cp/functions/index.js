const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// ===== USER MANAGEMENT FUNCTIONS =====

// Send push notification on new connection request
exports.sendNotificationOnConnectionRequest = functions.firestore
  .document('connectionRequests/{requestId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const toUserId = data.to;
    const fromUserId = data.from;
    
    try {
      // Get recipient's FCM token
    const userSnap = await admin.firestore().collection('users').doc(toUserId).get();
      const fcmToken = userSnap.data()?.fcmToken;
      
    if (fcmToken) {
        // Get sender's name
        const senderSnap = await admin.firestore().collection('users').doc(fromUserId).get();
        const senderName = senderSnap.data()?.name || 'Someone';
        
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: 'New Connection Request',
            body: `${senderName} wants to connect with you!`,
        },
        data: {
          type: 'connection_request',
            from: fromUserId,
            requestId: context.params.requestId,
          },
        });
      }
    } catch (error) {
      console.error('Error sending connection request notification:', error);
    }
  });

// Send notification when connection request is accepted
exports.sendConnectionAcceptedNotification = functions.firestore
  .document('connectionRequests/{requestId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    if (beforeData.status === 'pending' && afterData.status === 'accepted') {
      const fromUserId = afterData.from;
      
      try {
        // Get sender's FCM token
        const userSnap = await admin.firestore().collection('users').doc(fromUserId).get();
        const fcmToken = userSnap.data()?.fcmToken;
        
        if (fcmToken) {
          // Get acceptor's name
          const acceptorSnap = await admin.firestore().collection('users').doc(afterData.to).get();
          const acceptorName = acceptorSnap.data()?.name || 'Someone';
          
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: 'Connection Accepted!',
              body: `${acceptorName} accepted your connection request!`,
            },
            data: {
              type: 'connection_accepted',
              from: afterData.to,
            },
          });
        }
      } catch (error) {
        console.error('Error sending connection accepted notification:', error);
      }
    }
  });

// ===== CHAT FUNCTIONS =====

// Send notification for new individual messages
exports.sendMessageNotification = functions.database
  .ref('/messages/{chatId}/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.val();
    const senderId = messageData.senderId;
    const chatId = context.params.chatId;
    
    try {
      // Get chat room info
      const chatRoomSnap = await admin.database().ref(`/chatRooms/${chatId}`).once('value');
      const chatRoomData = chatRoomSnap.val();
      
      if (!chatRoomData) return;
      
      // Find recipient (not sender)
      const recipientId = chatRoomData.participants.find(id => id !== senderId);
      if (!recipientId) return;
      
      // Get recipient's FCM token
      const userSnap = await admin.firestore().collection('users').doc(recipientId).get();
      const fcmToken = userSnap.data()?.fcmToken;
      
      if (fcmToken) {
        // Get sender's name
        const senderSnap = await admin.firestore().collection('users').doc(senderId).get();
        const senderName = senderSnap.data()?.name || 'Someone';
        
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: `Message from ${senderName}`,
            body: messageData.text.length > 50 ? `${messageData.text.substring(0, 50)}...` : messageData.text,
          },
          data: {
            type: 'message',
            chatId: chatId,
            senderId: senderId,
          },
        });
      }
    } catch (error) {
      console.error('Error sending message notification:', error);
    }
  });

// Send notification for new group messages
exports.sendGroupMessageNotification = functions.database
  .ref('/groupMessages/{groupId}/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.val();
    const senderId = messageData.senderId;
    const groupId = context.params.groupId;
    
    try {
      // Get group members
      const groupMembersSnap = await admin.firestore()
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .get();
      
      // Get sender and group info
      const senderSnap = await admin.firestore().collection('users').doc(senderId).get();
      const groupSnap = await admin.firestore().collection('groups').doc(groupId).get();
      
      const senderName = senderSnap.data()?.name || 'Someone';
      const groupName = groupSnap.data()?.name || 'Group';
      
      // Send notification to all group members except sender
      const notificationPromises = groupMembersSnap.docs
        .filter(doc => doc.id !== senderId)
        .map(async (memberDoc) => {
          const memberId = memberDoc.id;
          const userSnap = await admin.firestore().collection('users').doc(memberId).get();
          const fcmToken = userSnap.data()?.fcmToken;
          
          if (fcmToken) {
            return admin.messaging().send({
              token: fcmToken,
              notification: {
                title: `${senderName} in ${groupName}`,
                body: messageData.text.length > 50 ? `${messageData.text.substring(0, 50)}...` : messageData.text,
              },
              data: {
                type: 'group_message',
                groupId: groupId,
                senderId: senderId,
              },
            });
          }
        });
      
      await Promise.all(notificationPromises.filter(Boolean));
    } catch (error) {
      console.error('Error sending group message notification:', error);
    }
  });

// Clean up typing indicators after 10 seconds
exports.cleanupTypingIndicators = functions.pubsub
  .schedule('every 10 seconds')
  .onRun(async (context) => {
    try {
      const now = Date.now();
      const cutoffTime = now - 10000; // 10 seconds ago
      
      // Clean up individual typing indicators
      const individualTypingRef = admin.database().ref('/typing');
      const individualSnap = await individualTypingRef.once('value');
      const individualData = individualSnap.val();
      
      if (individualData) {
        const cleanupPromises = [];
        Object.keys(individualData).forEach(chatId => {
          Object.keys(individualData[chatId]).forEach(userId => {
            const typingData = individualData[chatId][userId];
            if (typingData.timestamp < cutoffTime) {
              cleanupPromises.push(
                individualTypingRef.child(`${chatId}/${userId}`).remove()
              );
            }
          });
        });
        await Promise.all(cleanupPromises);
      }
      
      // Clean up group typing indicators
      const groupTypingRef = admin.database().ref('/groupTyping');
      const groupSnap = await groupTypingRef.once('value');
      const groupData = groupSnap.val();
      
      if (groupData) {
        const cleanupPromises = [];
        Object.keys(groupData).forEach(groupId => {
          Object.keys(groupData[groupId]).forEach(userId => {
            const typingData = groupData[groupId][userId];
            if (typingData.timestamp < cutoffTime) {
              cleanupPromises.push(
                groupTypingRef.child(`${groupId}/${userId}`).remove()
              );
            }
          });
        });
        await Promise.all(cleanupPromises);
      }
    } catch (error) {
      console.error('Error cleaning up typing indicators:', error);
    }
  });

// ===== GROUP MANAGEMENT FUNCTIONS =====

// Send notification when user is invited to a group
exports.sendGroupInvitationNotification = functions.firestore
  .document('group_invitations/{invitationId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const invitedTo = data.invitedTo;
    const invitedBy = data.invitedBy;
    const groupId = data.groupId;
    
    try {
      // Get invitee's FCM token
      const userSnap = await admin.firestore().collection('users').doc(invitedTo).get();
      const fcmToken = userSnap.data()?.fcmToken;
      
      if (fcmToken) {
        // Get inviter and group info
        const inviterSnap = await admin.firestore().collection('users').doc(invitedBy).get();
        const groupSnap = await admin.firestore().collection('groups').doc(groupId).get();
        
        const inviterName = inviterSnap.data()?.name || 'Someone';
        const groupName = groupSnap.data()?.name || 'a group';
        
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: 'Group Invitation',
            body: `${inviterName} invited you to join ${groupName}`,
          },
          data: {
            type: 'group_invitation',
            groupId: groupId,
            invitedBy: invitedBy,
            invitationId: context.params.invitationId,
          },
        });
      }
    } catch (error) {
      console.error('Error sending group invitation notification:', error);
    }
  });

// ===== ANALYTICS FUNCTIONS =====

// Track user activity
exports.trackUserActivity = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const userId = context.params.userId;
    
    try {
      // Track profile updates
      if (JSON.stringify(beforeData) !== JSON.stringify(afterData)) {
        await admin.firestore().collection('userActivity').add({
          userId: userId,
          activityType: 'profile_update',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          changes: {
            before: beforeData,
            after: afterData,
          },
        });
      }
    } catch (error) {
      console.error('Error tracking user activity:', error);
    }
  });

// Track message activity
exports.trackMessageActivity = functions.database
  .ref('/messages/{chatId}/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.val();
    const chatId = context.params.chatId;
    
    try {
      await admin.firestore().collection('analytics').add({
        eventType: 'message_sent',
        chatId: chatId,
        senderId: messageData.senderId,
        messageLength: messageData.text.length,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('Error tracking message activity:', error);
    }
  });

// ===== SECURITY FUNCTIONS =====

// Rate limiting for connection requests
exports.rateLimitConnectionRequests = functions.firestore
  .document('connectionRequests/{requestId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const fromUserId = data.from;
    
    try {
      // Check how many requests this user has sent in the last hour
      const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
      const recentRequests = await admin.firestore()
        .collection('connectionRequests')
        .where('from', '==', fromUserId)
        .where('timestamp', '>', oneHourAgo)
        .get();
      
      if (recentRequests.size > 10) {
        // Delete the request and log the violation
        await snap.ref.delete();
        
        await admin.firestore().collection('securityViolations').add({
          userId: fromUserId,
          violationType: 'rate_limit_exceeded',
          action: 'connection_requests',
          limit: 10,
          timeframe: '1 hour',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        throw new functions.https.HttpsError(
          'resource-exhausted',
          'Rate limit exceeded. Please wait before sending more connection requests.'
        );
      }
    } catch (error) {
      console.error('Error in rate limiting:', error);
      throw error;
    }
  });

// ===== UTILITY FUNCTIONS =====

// Update user's last seen timestamp
exports.updateLastSeen = functions.database
  .ref('/onlineStatus/{userId}')
  .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const newData = change.after.val();
    
    if (newData && newData.isOnline === false) {
      try {
        await admin.firestore().collection('users').doc(userId).update({
          lastSeen: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        console.error('Error updating last seen:', error);
      }
    }
  });

// Clean up old notifications (older than 30 days)
exports.cleanupOldNotifications = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    try {
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
      
      const oldNotifications = await admin.firestore()
        .collection('notifications')
        .where('timestamp', '<', thirtyDaysAgo)
        .get();
      
      const batch = admin.firestore().batch();
      oldNotifications.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      
      await batch.commit();
      console.log(`Cleaned up ${oldNotifications.size} old notifications`);
    } catch (error) {
      console.error('Error cleaning up old notifications:', error);
    }
  }); 