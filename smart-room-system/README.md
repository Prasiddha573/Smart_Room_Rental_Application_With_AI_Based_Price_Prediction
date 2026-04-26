<div align="center">
  <h1>🏠 smart-room</h1>
  <h3>🚀 AI-powered Smart Room Rental & Booking Platform</h3>
  <p>
    A modern Flutter + Firebase application that uses AI-based price prediction, 
    smart room prioritization, and real-time booking updates to help users find the best rooms effortlessly.
  </p>
</div>

<hr>

<h2>🌟 Features</h2>

<h3>🔍 Smart Listing Logic</h3>
<ul>
  <li>Shows <strong>Book Now</strong>, <strong>Pre-book</strong>, or <strong>Already Booked</strong> automatically.</li>
  <li>Recently uploaded rooms (within 24 hours) show <strong>Pre-book</strong>.</li>
  <li>Booked rooms move to the bottom of the list with disabled buttons.</li>
</ul>

<h3>🤖 AI Room Pricing</h3>
<ul>
  <li>Compares owner price with AI-predicted price.</li>
  <li>Highlights <strong>Best Cheapest Room</strong> when owner price is lower.</li>
  <li>Displays both owner and AI prices side-by-side.</li>
</ul>

<h3>🏠 Full Room Details</h3>
<p>
  Each room includes complete data: doors, windows, bathrooms, water, electricity, room size, KU gate distance, amenities, images, and more.
</p>

<h3>🔎 Search & Filters</h3>
<ul>
  <li>Price range filtering</li>
  <li>Distance filtering</li>
  <li>Room size filtering</li>
  <li>Amenities filtering</li>
</ul>

<h3>📩 Booking Flow</h3>
<ul>
  <li>User sends Book / Pre-book request.</li>
  <li>Owner receives confirmation.</li>
  <li>Firebase updates the room’s status instantly.</li>
  <li>Booked rooms become locked for other users.</li>
</ul>

<hr>

<h2>🧱 Tech Stack</h2>

<table>
  <tr>
    <th>Category</th>
    <th>Technologies</th>
  </tr>
  <tr>
    <td>Frontend</td>
    <td>Flutter, Dart</td>
  </tr>
  <tr>
    <td>Backend</td>
    <td>Firebase Firestore, Firebase Auth</td>
  </tr>
  <tr>
    <td>AI / ML</td>
    <td>TensorFlow Lite / Custom AI Model</td>
  </tr>
  <tr>
    <td>Storage</td>
    <td>Firebase Storage</td>
  </tr>
  <tr>
    <td>Architecture</td>
    <td>MVVM / Clean Architecture</td>
  </tr>
</table>

<hr>

<h2>📂 Project Structure</h2>

<pre>
smart-room/
 ├── lib/
 │   ├── controllers/     # GetX controllers
 │   ├── models/          # Data models / dummy data
 │   ├── screens/         # App screens (UI)
 │   │   ├── auth/
 │   │   ├── home/
 │   │   ├── owner/
 │   │   ├── user/
 │   ├── themes/          # App themes, colors
 │   ├── utils/           # Helper functions, constants, validators
 │   ├── widgets/         # Custom reusable widgets
 │   └── main.dart        # App entry point
 ├── assets/              # Images, icons, fonts
 │   ├── fonts/          
 │   └── images/
 ├── firebase/            # Firebase configuration
 ├── README.md
 └── pubspec.yaml
</pre>

<hr>

<h2>⚡ Installation</h2>

<pre>
git clone https://github.com/Prasiddha573/smart-room
cd smart-room
flutter pub get
flutter run
</pre>

<hr>

<h2>📝 Roadmap</h2>
<ul>
  <li>[ ] Admin dashboard</li>
  <li>[ ] AI-based smart room recommendations</li>
  <li>[ ] Built-in owner/user chat system</li>
  <li>[ ] Online payment integration</li>
  <li>[ ] Multi-city support</li>
</ul>

<hr>

<h2>🤝 Contributing</h2>
<p>Pull requests are welcome! Open an issue to discuss improvements.</p>

<hr>

<br><br>

<div align="center">
  <h3>⭐ If you like this project, give it a star on GitHub!</h3>
</div>
