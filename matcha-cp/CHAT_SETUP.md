# Chat Setup Guide

## Firebase Realtime Database Configuration

To enable real-time messaging functionality like WhatsApp with typing indicators and online status, you need to configure Firebase Realtime Database with the following security rules.

### 1. Firebase Console Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (`matche-39f37`)
3. Navigate to **Realtime Database** in the left sidebar
4. If not already created, click **Create Database**
5. Choose a location (preferably close to your users)
6. Start in **test mode** for initial setup

### 2. Security Rules

Replace the default rules with the following:

```json
{
  "rules": {
    "chatRooms": {
      "$chatId": {
        ".read": "data.child('participants').hasChild(auth.uid)",
        ".write": "data.child('participants').hasChild(auth.uid) || !data.exists()"
      }
    },
    "messages": {
      "$chatId": {
        ".read": "root.child('chatRooms').child($chatId).child('participants').hasChild(auth.uid)",
        ".write": "root.child('chatRooms').child($chatId).child('participants').hasChild(auth.uid)"
      }
    },
    "groupChatRooms": {
      "$groupId": {
        ".read": "root.child('groups').child($groupId).child('members').hasChild(auth.uid)",
        ".write": "root.child('groups').child($groupId).child('members').hasChild(auth.uid)"
      }
    },
    "groupMessages": {
      "$groupId": {
        ".read": "root.child('groups').child($groupId).child('members').hasChild(auth.uid)",
        ".write": "root.child('groups').child($groupId).child('members').hasChild(auth.uid)"
      }
    },
    "typing": {
      "$chatId": {
        ".read": "root.child('chatRooms').child($chatId).child('participants').hasChild(auth.uid)",
        ".write": "root.child('chatRooms').child($chatId).child('participants').hasChild(auth.uid)"
      }
    },
    "groupTyping": {
      "$groupId": {
        ".read": "root.child('groups').child($groupId).child('members').hasChild(auth.uid)",
        ".write": "root.child('groups').child($groupId).child('members').hasChild(auth.uid)"
      }
    },
    "onlineStatus": {
      "$userId": {
        ".read": "auth.uid != null",
        ".write": "auth.uid == $userId"
      }
    }
  }
}
```

### 3. Database Structure

The enhanced chat system uses the following structure:

```
chatRooms/
  {chatId}/
    chatId: "user1_user2"
    type: "individual"
    participants: ["user1", "user2"]
    lastMessage: "Hello!"
    lastMessageTime: 1234567890
    lastMessageSender: "user1"
    unreadCount: {
      "user1": 0,
      "user2": 1
    }
    createdAt: 1234567890
    updatedAt: 1234567890

messages/
  {chatId}/
    {messageId}/
      messageId: "msg123"
      senderId: "user1"
      text: "Hello!"
      timestamp: 1234567890
      type: "text"
      status: "sent"
      readBy: ["user1"]

typing/
  {chatId}/
    {userId}/
      isTyping: true
      timestamp: 1234567890
      startTime: 1234567890

onlineStatus/
  {userId}/
    isOnline: true
    lastSeen: 1234567890
    timestamp: 1234567890
```

### 4. Features

#### Real-time Messaging
- **Instant Message Delivery**: Messages appear in real-time for both sender and receiver
- **Message Status**: Shows sent (✓), delivered (✓✓), and read (✓✓ blue) indicators
- **Message Timestamps**: Displays time for each message
- **Unread Count**: Shows number of unread messages in chat list

#### Typing Indicators (3 Dots Animation)
- **Individual Chats**: Shows "User is typing..." with animated 3 dots
- **Group Chats**: Shows "User1 and User2 are typing..." or "User1 and 2 others are typing..."
- **Auto-hide**: Typing indicator disappears after 10 seconds of inactivity
- **Real-time Updates**: Updates instantly when users start/stop typing

#### Online Status
- **Green Dot Indicator**: Shows green dot on user avatars when they're online
- **App Lifecycle Management**: Automatically sets online/offline based on app state
- **Real-time Updates**: Online status updates instantly across all users
- **Chat List Integration**: Shows online status in chat list

#### Enhanced UI
- **WhatsApp-like Design**: Modern chat interface with message bubbles
- **Online Avatar Widget**: Custom CircleAvatar with online status indicator
- **Typing Indicator Widget**: Animated 3 dots like WhatsApp
- **Message Bubbles**: Different colors for sent vs received messages

### 5. Testing the Chat

1. **Start Individual Chat:**
   - Go to Messages tab
   - Tap the floating action button
   - Select "New Individual Chat"
   - Choose a user from your connections
   - Tap to start chatting

2. **Test Typing Indicators:**
   - Start typing in the message input
   - Other users should see "User is typing..." with animated dots
   - Stop typing for 2 seconds - indicator should disappear

3. **Test Online Status:**
   - Users should see green dots on online users' avatars
   - Online status should update when app goes to background/foreground
   - Chat list should show online/offline status

4. **Send Messages:**
   - Type a message in the input field
   - Tap the send button or press Enter
   - Messages should appear in real-time
   - Check message status indicators (sent, delivered, read)

### 6. Common Issues and Solutions

**Issue: "Failed to initialize chat"**
- Check Firebase Realtime Database is enabled
- Verify security rules are properly set
- Ensure user is authenticated

**Issue: "Error loading messages"**
- Check network connectivity
- Verify Firebase configuration in `firebase_options.dart`
- Check console logs for specific error messages

**Issue: Messages not appearing in real-time**
- Verify Firebase Realtime Database URL is correct
- Check that listeners are properly set up
- Ensure proper error handling in streams

**Issue: Typing indicators not working**
- Check typing rules in Firebase Realtime Database
- Verify typing status is being set correctly
- Check console logs for typing-related errors

**Issue: Online status not updating**
- Check online status rules in Firebase Realtime Database
- Verify app lifecycle management is working
- Check console logs for online status errors

### 7. Debugging

Enable debug logging by checking the console output. The app will print:
- Chat room creation/retrieval
- Message sending/receiving
- Typing status updates
- Online status changes
- Error messages with details

### 8. Security Notes

- Users can only access chats they are participants in
- Messages are only visible to chat participants
- Typing indicators are only shown to other participants
- Online status is readable by all authenticated users but only writable by the user themselves
- All operations require authentication

### 9. Performance Considerations

- Messages are ordered by timestamp
- Chat rooms are ordered by last activity
- Unread counts are maintained per user
- Real-time listeners are properly disposed when screens are closed
- Typing indicators auto-hide after 10 seconds
- Online status updates are batched to reduce database calls

### 10. WhatsApp-like Features Implemented

✅ **Real-time messaging** - Instant message delivery  
✅ **Typing indicators** - Animated 3 dots like WhatsApp  
✅ **Online status** - Green dot on avatars  
✅ **Message status** - Sent, delivered, read indicators  
✅ **Unread counts** - Badge on chat list  
✅ **Message timestamps** - Time display for messages  
✅ **Modern UI** - WhatsApp-like design  
✅ **App lifecycle management** - Auto online/offline  
✅ **Group chat support** - Multiple typing indicators  
✅ **Error handling** - Robust error recovery 