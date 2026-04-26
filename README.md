# Smart Room - AI-Powered Room Rental & Booking Platform

A full-stack room rental system consisting of a **Flutter mobile app** for browsing, booking, and chatting about rooms, and a **Python ML backend** that predicts monthly rental prices using a trained Gradient Boosting model.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Setup & Installation](#setup--installation)
  - [1. ML Model Training & Flask API](#1-ml-model-training--flask-api)
  - [2. Flutter App](#2-flutter-app)
- [Usage](#usage)
  - [Adding a Room with AI Price Estimation](#adding-a-room-with-ai-price-estimation)
  - [Chatting with Room Owners](#chatting-with-room-owners)
  - [Booking a Room](#booking-a-room)
- [API Reference](#api-reference)
- [Firebase Data Schema](#firebase-data-schema)
- [Configuration](#configuration)
- [Roadmap](#roadmap)

---

## Overview

Smart Room is built for students and tenants looking for rooms near Kathmandu University (KU). It solves two key problems:

1. **Fair Pricing** - Room owners fill in details (size, location, amenities) and the app calls an ML model to predict a fair monthly rent. The owner can adjust the price, and both the AI-predicted and final prices are displayed to tenants so they can make informed decisions.

2. **Direct Communication** - Tenants can chat directly with room owners from the room details screen. Conversations are persisted in Firebase and accessible from the Chat tab.

---

## Architecture

```
+-------------------+        HTTP POST /predict        +-------------------+
|                   | --------------------------------> |                   |
|   Flutter App     |                                   |   Flask API       |
|   (smart-room)    | <-------------------------------- |   (Python)        |
|                   |        { predicted_price }        |                   |
+--------+----------+                                   +--------+----------+
         |                                                       |
         |  Firestore / Auth                                     |  joblib
         v                                                       v
+-------------------+                                   +-------------------+
|   Firebase        |                                   |   Trained Model   |
|   - Auth          |                                   |   (GradientBoost) |
|   - Firestore     |                                   |   .pkl files      |
|   - room          |                                   +-------------------+
|   - User          |
|   - bookings      |
|   - chat_users    |
|   - chats         |
+-------------------+
         |
         v
+-------------------+
|   Supabase        |
|   - room_images   |
|   - chat-images   |
+-------------------+
```

---

## Project Structure

```
Prasiddha code/
├── smart-room-system/              # Flutter mobile app
│   ├── lib/
│   │   ├── chat/                   # Chat feature
│   │   │   ├── helper/             # Date utilities, dialogs
│   │   │   ├── models/             # ChatUser, ChatMessage, Conversation
│   │   │   ├── screens/            # ChatHomeScreen, ChatScreen
│   │   │   ├── services/           # ChatService (Firestore CRUD)
│   │   │   └── widgets/            # ProfileImage widget
│   │   ├── config.dart             # API URLs, Supabase keys, Firebase config
│   │   ├── controllers/            # GetX controllers (auth, loader, password)
│   │   ├── firebase_options.dart   # Auto-generated Firebase config
│   │   ├── main.dart               # App entry point
│   │   ├── models/                 # UserModel
│   │   ├── screens/
│   │   │   ├── auth/               # Login, Signup screens + widgets
│   │   │   ├── home/               # HomeScreen, RoomDetails, OwnerDialog,
│   │   │   │                       # BookRoom, LocationPicker, SplashScreen
│   │   │   ├── main/               # MainScreen (bottom nav with 4 tabs)
│   │   │   ├── owner/              # OwnerScreen, OwnerRoomDetailsDialog
│   │   │   └── user/               # ProfileScreen
│   │   ├── services/               # AuthService, ToastService
│   │   ├── themes/                 # App colors
│   │   └── widgets/                # ModernAppBar
│   ├── pubspec.yaml
│   └── README.md
│
├── model_train_room_rental/        # ML model + API server
│   ├── train.ipynb                 # Jupyter notebook for model training
│   ├── train copy.ipynb            # Backup notebook
│   ├── app.py                      # Flask API server
│   ├── requirements.txt            # Python dependencies
│   ├── room_price_model.pkl        # Saved model (generated after training)
│   └── model_columns.pkl           # Saved column names (generated after training)
│
└── README.md                       # This file
```

---

## Features

### Room Listing & Discovery
- Browse available rooms with images, amenities, and prices
- Smart listing logic: shows "Book Now", "Pre-book", or "Already Booked" automatically
- Recently uploaded rooms (within 24 hours) show "Pre-book"
- Booked rooms move to the bottom with disabled buttons
- Price range, distance, and amenity filters

### AI Price Estimation
- Room owners fill in details (size, location, internet speed, windows, water, sunlight, bathroom)
- Press "Estimate" to get an AI-predicted monthly rent from the Gradient Boosting model
- The predicted price is saved as `aiPrice`
- Owners can edit the price before publishing; edited price is saved as `price`
- Both prices are displayed to tenants for transparency

### Real-Time Chat
- Tenants can open a chat with any room owner directly from the room details screen
- Chat conversations are persisted in Firestore and appear in the Chat tab
- Supports text and image messages
- Optimistic message updates for instant feedback
- Unread message counts and favorite conversations

### Room Booking
- Tenants send booking requests to room owners
- Owners can accept or reject requests
- Room status updates in real-time via Firestore

### Interactive Map
- Pick room location on Google Maps
- Distance from KU and walk time calculated automatically
- View room location with polyline route from your current position

### Authentication
- Email/password authentication via Firebase Auth
- User profiles stored in Firestore
- Profile editing with image upload to Supabase

---

## Tech Stack

| Layer        | Technology                                                     |
|--------------|----------------------------------------------------------------|
| Mobile App   | Flutter (Dart), GetX for state management                      |
| Backend      | Firebase Auth, Cloud Firestore                                 |
| Storage      | Supabase Storage (room images, chat images)                    |
| Maps         | Google Maps Flutter, Geolocator                                |
| ML Model     | scikit-learn (GradientBoostingRegressor), trained on 30K rooms |
| ML API       | Flask (Python), served via gunicorn for production              |
| UI           | Google Fonts (Quicksand), Material Design, Shimmer loading     |

---

## Prerequisites

- **Flutter SDK** >= 3.0.0
- **Dart** >= 3.0.0
- **Python** >= 3.8
- **pip** (Python package manager)
- **Jupyter Notebook** (for model training)
- **Firebase project** with Auth and Firestore enabled
- **Supabase project** with a `room_images` storage bucket
- **Google Maps API key** (for Android/iOS)
- The training dataset CSV file (30,000 room records)

---

## Setup & Installation

### 1. ML Model Training & Flask API

```bash
# Navigate to the ML project
cd "model_train_room_rental"

# Install Python dependencies
pip install -r requirements.txt

# Open the training notebook
jupyter notebook train.ipynb
```

**In the notebook:**

1. Update the dataset path in Cell 1 (`rooms = pd.read_csv("...")`) to point to your CSV file.
2. Run all cells from Cell 0 through Cell 19.
3. Cell 19 saves the model as `room_price_model.pkl` and columns as `model_columns.pkl`.

**Start the Flask API:**

```bash
# Development
python app.py

# Production
gunicorn app:app --bind 0.0.0.0:5000
```

The API will be available at `http://localhost:5000`.

**Verify it's working:**

```bash
# Health check
curl http://localhost:5000/health

# Test prediction
curl -X POST http://localhost:5000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "distance": 1.07,
    "internet": 250,
    "windows": 5,
    "bathroom": "yes",
    "size": 250,
    "water": "available",
    "sunlight": "good"
  }'
```

Expected response:
```json
{
  "predicted_price": 5500,
  "input_features": {
    "distance_from_KU_km": 1.07,
    "internet_speed_mbps": 250,
    "windows": 5,
    "attached_bathroom": 2,
    "water_availability": 1,
    "sunlight": 2,
    "room_area": 250
  }
}
```

### 2. Flutter App

```bash
# Navigate to the Flutter project
cd "smart-room-system"

# Install dependencies
flutter pub get

# Update the API URL in lib/config.dart:
# - Android emulator:    http://10.0.2.2:5000/predict
# - Physical device:     http://<your-local-ip>:5000/predict
# - iOS simulator:       http://localhost:5000/predict

# Run the app
flutter run
```

---

## Usage

### Adding a Room with AI Price Estimation

1. Tap the **+** button in the top-right corner of the home screen
2. Fill in room details:
   - Room name
   - Internet speed (Mbps)
   - Number of windows
   - Room size (sq ft)
   - Location (pick on map)
   - Water availability, Sunlight, Bathroom (toggle selectors)
3. Add up to 6 room images
4. Press **"Estimate"** - the app sends the room features to the Flask API
5. The AI-predicted price appears with an editable field
6. Adjust the price if needed (or leave as-is)
7. Press **"Publish"** to list the room
8. Both `aiPrice` (original prediction) and `price` (final/edited) are saved to Firestore

### Chatting with Room Owners

1. From the home screen, tap **"View Details"** on any room card
2. In the room details sheet, tap the **"Chat"** button
3. A conversation is created (or resumed if one already exists) with the room owner
4. You are taken directly to the chat screen to start messaging
5. The conversation also appears in the **Chat tab** of the main screen

### Booking a Room

1. From the room details sheet, tap **"Book"**
2. Confirm the booking request
3. The room owner receives the request and can accept or reject it
4. Room status updates in real-time across all users

---

## API Reference

### `POST /predict`

Predicts monthly room rental price in NPR.

**Request body (JSON):**

| Field      | Type             | Description                                | Example       |
|------------|------------------|--------------------------------------------|---------------|
| `distance` | number or string | Distance from KU in km                     | `1.07` or `"1.07 km"` |
| `internet` | number           | Internet speed in Mbps                     | `250`         |
| `windows`  | number           | Number of windows                          | `5`           |
| `bathroom` | string           | `"Yes"`, `"No"`, or `"Shared"`             | `"yes"`       |
| `size`     | number           | Room area in sq ft                         | `250`         |
| `water`    | string           | `"Available"`, `"Limited"`, or `"Always"`  | `"available"` |
| `sunlight` | string           | `"Good"`, `"Moderate"`, or `"Poor"`        | `"good"`      |

**Response (JSON):**

```json
{
  "predicted_price": 5500,
  "input_features": { ... }
}
```

### `GET /health`

Returns API health status and whether the model is loaded.

---

## Firebase Data Schema

### `room` collection
| Field       | Type      | Description                                  |
|-------------|-----------|----------------------------------------------|
| `roomName`  | string    | Name of the room                             |
| `internet`  | number    | Internet speed in Mbps                       |
| `windows`   | number    | Number of windows                            |
| `size`      | number    | Room area in sq ft                           |
| `location`  | string    | Coordinates string (e.g., "27.62 N, 85.53 E")|
| `latitude`  | number    | Latitude                                     |
| `longitude` | number    | Longitude                                    |
| `distance`  | string    | Distance from KU (e.g., "1.07 km")           |
| `walkTime`  | string    | Walk time (e.g., "15 min")                   |
| `water`     | string    | Water availability                           |
| `sunlight`  | string    | Sunlight quality                             |
| `bathroom`  | string    | Bathroom type                                |
| `price`     | number    | Final price set by owner (may be edited)     |
| `aiPrice`   | number    | AI-predicted price (original, never changed) |
| `images`    | array     | List of Supabase image URLs                  |
| `createdAt` | timestamp | Creation timestamp                           |
| `sessionId` | string    | Owner's Firebase Auth UID                    |
| `status`    | string    | "Available", "Requested", or "Booked"        |

### `User` collection
| Field       | Type      | Description              |
|-------------|-----------|--------------------------|
| `Name`      | string    | User's full name         |
| `Email`     | string    | Email address            |
| `Phone`     | string    | Phone number             |
| `SessionId` | string    | Firebase Auth UID        |
| `Path`      | string    | Profile image URL        |
| `createdAt` | timestamp | Account creation time    |

### `bookings` collection
| Field           | Type      | Description                          |
|-----------------|-----------|--------------------------------------|
| `bookingId`     | string    | Unique booking ID                    |
| `roomDocumentId`| string    | Reference to room document           |
| `userId`        | string    | Tenant's Firebase Auth UID           |
| `ownerId`       | string    | Owner's Firebase Auth UID            |
| `bookingStatus` | string    | "requested", "booked", or "rejected" |
| `bookingDate`   | timestamp | Booking date                         |

### `chat_users` collection (conversations)
| Field               | Type      | Description                     |
|---------------------|-----------|---------------------------------|
| `conversationId`    | string    | Sorted user IDs joined with "_" |
| `user1Id`           | string    | First user's UID                |
| `user2Id`           | string    | Second user's UID               |
| `users`             | array     | Both user UIDs                  |
| `lastMessage`       | string    | Last message text               |
| `lastMessageTime`   | timestamp | Timestamp of last message       |
| `lastMessageSenderId`| string   | Sender of last message          |
| `unreadCount`       | map       | Unread counts per user          |
| `isFavorite`        | map       | Favorite status per user        |

### `chats` collection (messages)
| Field            | Type      | Description              |
|------------------|-----------|--------------------------|
| `messageId`      | string    | Unique message ID        |
| `conversationId` | string    | Parent conversation ID   |
| `senderId`       | string    | Sender's UID             |
| `receiverId`     | string    | Receiver's UID           |
| `message`        | string    | Message content or URL   |
| `type`           | string    | "text" or "image"        |
| `timestamp`      | timestamp | Message timestamp        |
| `isRead`         | boolean   | Read status              |
| `isDeleted`      | boolean   | Deletion status          |

---

## Configuration

All configuration values are in `smart-room-system/lib/config.dart`:

| Constant                 | Description                                         |
|--------------------------|-----------------------------------------------------|
| `supabaseUrl`            | Supabase project URL                                |
| `supabaseAnonKey`        | Supabase anonymous key                              |
| `chatImagesBucket`       | Supabase bucket name for chat images                |
| `firebaseProjectId`      | Firebase project ID                                 |
| `priceEstimationApiUrl`  | Flask API prediction endpoint URL                   |

**Important:** Update `priceEstimationApiUrl` based on your deployment:

| Environment          | URL                                      |
|----------------------|------------------------------------------|
| Android Emulator     | `http://10.0.2.2:5000/predict`           |
| Physical Device      | `http://<your-local-ip>:5000/predict`    |
| iOS Simulator        | `http://localhost:5000/predict`          |
| Production           | `https://your-deployed-api.com/predict`  |

---

## ML Model Details

- **Algorithm:** Gradient Boosting Regressor (scikit-learn)
- **Training Data:** 30,000 room records near Kathmandu University
- **Performance:** R2 = 0.94, MAE = 199 NPR, RMSE = 255 NPR
- **Features used:**
  - `distance_from_KU_km` (float) - distance from KU in kilometers
  - `internet_speed_mbps` (int) - internet speed
  - `windows` (int) - number of windows
  - `attached_bathroom` (int: 0=no, 1=shared, 2=yes)
  - `water_availability` (int: 0=limited, 1=available, 2=24/7)
  - `sunlight` (int: 0=poor, 1=moderate, 2=good)
  - `room_area` (int) - room area in sq ft

---

## Roadmap

- [ ] Deploy Flask API to cloud (Railway / Render / AWS)
- [ ] Admin dashboard for managing listings
- [ ] AI-based smart room recommendations
- [ ] Online payment integration (Khalti / eSewa)
- [ ] Push notifications for booking updates and new messages
- [ ] Multi-city support beyond KU area
- [ ] Room review and rating system

---

