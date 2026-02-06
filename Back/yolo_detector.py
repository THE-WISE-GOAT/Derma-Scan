import cv2
import numpy as np
from ultralytics import YOLO  # type: ignore
import io

class SkinDetector:
    def __init__(self, model_path: str = "models/skin_trained.pt"):
        self.model = YOLO(model_path)

    def predict(self, image_bytes: bytes, confidence: float = 0.2):
        # Convert bytes to numpy array
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        # Check if image decoding was successful
        if img is None:
            raise ValueError("Could not decode image. Please ensure the file is a valid image format.")

        # Run inference
        results = self.model.predict(source=img, conf=confidence)

        # Process first result
        result = results[0]

        detections = []

        if result.boxes is not None:
            for box in result.boxes:
                detections.append({
                    "class": result.names[int(box.cls[0])],
                    "confidence": float(box.conf[0]),
                    "bbox": box.xyxy[0].tolist()
                })

        # Generate annotated image
        annotated_img = result.plot()
        _, buffer = cv2.imencode(".png", annotated_img)

        return {
            "detections": detections,
            "annotated_image_bytes": buffer.tobytes(),
            "count": len(detections),
            "raw_result": result
        }
