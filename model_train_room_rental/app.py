"""
Flask API for room price prediction.

This API serves the trained GradientBoosting model
to predict monthly room rental prices (NPR).

Run with:
    python app.py

Or for production:
    gunicorn app:app --bind 0.0.0.0:5000
"""

import os
import joblib
import numpy as np
from flask import Flask, request, jsonify

app = Flask(__name__)

# Load model and column names
MODEL_PATH = os.path.join(os.path.dirname(__file__), "room_price_model.pkl")
COLUMNS_PATH = os.path.join(os.path.dirname(__file__), "model_columns.pkl")

model = None
model_columns = None


def load_model():
    """Load the saved model and column names."""
    global model, model_columns
    if os.path.exists(MODEL_PATH) and os.path.exists(COLUMNS_PATH):
        model = joblib.load(MODEL_PATH)
        model_columns = joblib.load(COLUMNS_PATH)
        print(f"Model loaded. Expected columns: {model_columns}")
    else:
        print("WARNING: Model files not found. Run train.ipynb first to generate them.")


# Mappings from Flutter app values to model-encoded values
BATHROOM_MAP = {
    "yes": 2,
    "no": 0,
    "shared": 1,
}

WATER_MAP = {
    "available": 1,
    "limited": 0,
    "always": 2,      # "Always" in the app maps to "24/7 available" in the dataset
    "24/7 available": 2,
}

SUNLIGHT_MAP = {
    "good": 2,
    "moderate": 1,
    "poor": 0,
}


def parse_distance(distance_str):
    """
    Parse a distance string like '1.07 km' or '1.07' to a float value in km.
    """
    if isinstance(distance_str, (int, float)):
        return float(distance_str)
    # Remove 'km' and whitespace, then parse
    cleaned = distance_str.lower().replace("km", "").strip()
    return float(cleaned)


@app.route("/predict", methods=["POST"])
def predict():
    """
    Predict room rental price.

    Expects JSON body with fields:
    - distance: distance from KU in km (number or string like "1.07 km")
    - internet: internet speed in Mbps (number)
    - windows: number of windows (number)
    - bathroom: "Yes", "No", or "Shared"
    - size: room area in sq ft (number)
    - water: "Available", "Limited", or "Always"
    - sunlight: "Good", "Moderate", or "Poor"

    Returns JSON with:
    - predicted_price: the predicted monthly rent in NPR (integer)
    """
    if model is None:
        return jsonify({"error": "Model not loaded. Run train.ipynb first."}), 500

    try:
        data = request.get_json()
        if data is None:
            return jsonify({"error": "Request body must be JSON"}), 400

        # Parse and map input features
        distance = parse_distance(data.get("distance", 0))
        internet = int(data.get("internet", 0))
        windows = int(data.get("windows", 0))
        bathroom_str = str(data.get("bathroom", "no")).lower()
        size = int(data.get("size", 0))
        water_str = str(data.get("water", "limited")).lower()
        sunlight_str = str(data.get("sunlight", "poor")).lower()

        # Map categorical values
        bathroom_val = BATHROOM_MAP.get(bathroom_str, 0)
        water_val = WATER_MAP.get(water_str, 0)
        sunlight_val = SUNLIGHT_MAP.get(sunlight_str, 0)

        # Build feature array in the same order as model_columns
        # Expected columns: distance_from_KU_km, internet_speed_mbps, windows,
        #                    attached_bathroom, water_availability, sunlight, room_area
        feature_mapping = {
            "distance_from_KU_km": distance,
            "internet_speed_mbps": internet,
            "windows": windows,
            "attached_bathroom": bathroom_val,
            "water_availability": water_val,
            "sunlight": sunlight_val,
            "room_area": size,
        }

        features = []
        for col in model_columns:
            if col in feature_mapping:
                features.append(feature_mapping[col])
            else:
                features.append(0)  # default for unknown columns

        # Predict
        X = np.array([features])
        predicted_price = model.predict(X)[0]

        # Round to nearest integer
        predicted_price = int(round(predicted_price))

        return jsonify({
            "predicted_price": predicted_price,
            "input_features": feature_mapping,
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 400


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint."""
    return jsonify({
        "status": "ok",
        "model_loaded": model is not None,
    })


if __name__ == "__main__":
    load_model()
    app.run(host="0.0.0.0", port=5000, debug=True)
