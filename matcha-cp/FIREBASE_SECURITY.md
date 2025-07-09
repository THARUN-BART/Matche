# Firebase Security Rules Guide

This document explains the security rules implemented for your Matcha app and how to deploy them.

## Overview

The security rules ensure that:
- Only authenticated users can access the app
- Users can only access their own data and data they're authorized to see
- Data integrity is maintained
- Malicious access is prevented

## Firestore Security Rules

### Key Security Features

1. **Authentication Required**: All operations require user authentication
2. **Owner-Based Access**: Users can only modify their own data
3. **Role-Based Access**: Group admins have additional privileges
4. **Data Validation**: Input data is validated before storage
5. **Connection Verification**: Users can only interact with connected users

### Collections and Rules

#### Users Collection (`/users/{userId}`)
- **Read**: All authenticated users can read user profiles
- **Create**: Users can create their own profile with valid data
- **Update**: Users can only update their own profile
- **Delete**: Disabled for data integrity

#### Connection Requests (`/connectionRequests/{requestId}`)
- **Read**: Users can read requests they sent or received
- **Create**: Users can send requests to others (not themselves)
- **Update**: Both sender and recipient can update request status
- **Delete**: Disabled to maintain request history

#### Groups (`/groups/{groupId}`)
- **Read**: All authenticated users can read group info
- **Create**: Authenticated users can create groups
- **Update**: Only group admins can update group settings
- **Delete**: Only group admins can delete groups

#### Notifications (`/notifications/{notificationId}`)
- **Read**: Users can only read notifications sent to them
- **Create**: Any authenticated user can create notifications
- **Update**: Users can mark their notifications as read
- **Delete**: Users can delete their own notifications

#### Messages (`/messages/{messageId}`)
- **Read/Write**: All authenticated users (for individual chats)
- **Group Messages**: Only group members can access

### Helper Functions

```javascript
// Check if user is authenticated
function isAuthenticated() {
  return request.auth != null;
}

// Check if user owns the data
function isOwner(userId) {
  return isAuthenticated() && request.auth.uid == userId;
}

// Check if user is group member
function isGroupMember(groupId) {
  return isAuthenticated() && 
    exists(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid));
}

// Check if user is group admin
function isGroupAdmin(groupId) {
  return isAuthenticated() && 
    get(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid)).data.role == 'admin';
}
```

## Firebase Storage Rules

### Key Features

1. **File Type Validation**: Only specific file types are allowed
2. **Size Limits**: Files are limited to reasonable sizes
3. **Owner-Based Access**: Users can only upload to their own folders
4. **Group-Based Access**: Group members can upload to group folders

### Storage Paths

#### User Files (`/users/{userId}/profile/`)
- **Read**: All authenticated users
- **Write**: Only the user can upload profile pictures
- **Limits**: Images only, max 5MB

#### Group Files (`/groups/{groupId}/media/`)
- **Read**: All authenticated users
- **Write**: Only group members can upload
- **Limits**: Media files, max 50MB

#### Chat Files (`/chats/{chatId}/media/`)
- **Read/Write**: All authenticated users
- **Limits**: Media files, max 50MB

## Deployment Instructions

### Using Firebase CLI

1. **Install Firebase CLI** (if not already installed):
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**:
   ```bash
   firebase login
   ```

3. **Initialize Firebase** (if not already done):
   ```bash
   firebase init
   ```

4. **Deploy Firestore Rules**:
   ```bash
   firebase deploy --only firestore:rules
   ```

5. **Deploy Storage Rules**:
   ```bash
   firebase deploy --only storage
   ```

6. **Deploy All Rules**:
   ```bash
   firebase deploy --only firestore:rules,storage
   ```

### Using Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to Firestore Database → Rules
4. Copy and paste the contents of `firestore.rules`
5. Click "Publish"
6. Navigate to Storage → Rules
7. Copy and paste the contents of `storage.rules`
8. Click "Publish"

## Testing Security Rules

### Using Firebase Emulator

1. **Start the emulator**:
   ```bash
   firebase emulators:start
   ```

2. **Test rules locally**:
   ```bash
   firebase emulators:exec --only firestore,storage
   ```

### Using Firebase Console

1. Go to Firestore Database → Rules
2. Click "Rules Playground"
3. Test different scenarios:
   - Authenticated vs unauthenticated access
   - Owner vs non-owner access
   - Admin vs member access

## Security Best Practices

### Data Validation
- Always validate input data before storing
- Use helper functions to check data integrity
- Implement size limits for uploads

### Access Control
- Follow the principle of least privilege
- Use role-based access control
- Verify user permissions before operations

### Monitoring
- Enable Firestore audit logs
- Monitor for suspicious activity
- Set up alerts for unusual access patterns

## Common Security Issues

### 1. Overly Permissive Rules
❌ **Bad**:
```javascript
allow read, write: if true;
```

✅ **Good**:
```javascript
allow read: if isAuthenticated();
allow write: if isOwner(userId);
```

### 2. Missing Authentication Checks
❌ **Bad**:
```javascript
allow read: if resource.data.public == true;
```

✅ **Good**:
```javascript
allow read: if isAuthenticated() && resource.data.public == true;
```

### 3. Insufficient Data Validation
❌ **Bad**:
```javascript
allow create: if isAuthenticated();
```

✅ **Good**:
```javascript
allow create: if isAuthenticated() && isValidUserData();
```

## Troubleshooting

### Common Errors

1. **Permission Denied**
   - Check if user is authenticated
   - Verify user has proper permissions
   - Check if data exists

2. **Missing Fields**
   - Ensure all required fields are present
   - Check data validation rules

3. **Size Limits Exceeded**
   - Check file size limits in storage rules
   - Implement client-side validation

### Debugging Tips

1. **Enable Debug Logs**:
   ```javascript
   firebase.firestore().settings({
     debug: true
   });
   ```

2. **Check Authentication State**:
   ```javascript
   firebase.auth().onAuthStateChanged((user) => {
     console.log('User:', user);
   });
   ```

3. **Test Rules Locally**:
   Use Firebase emulator for testing before deployment

## Updates and Maintenance

### Regular Reviews
- Review security rules monthly
- Update rules when adding new features
- Monitor for security vulnerabilities

### Version Control
- Keep rules in version control
- Document all changes
- Test thoroughly before deployment

### Backup
- Keep backup of current rules
- Document rollback procedures
- Test rollback scenarios

## Support

For issues with security rules:
1. Check Firebase documentation
2. Review error messages carefully
3. Test with Firebase emulator
4. Contact Firebase support if needed

---

**Note**: These rules are designed for the Matcha app structure. Modify them according to your specific needs and requirements. 