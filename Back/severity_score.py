import joblib
import pandas as pd
import numpy as np

class SeverityAnalyzer:
    FEATURE_NAMES = [
        'num_detections', 'mean_conf', 'max_conf', 'total_area_capped', 
        'density', 'rare_class_count', 'class_0_count', 'class_1_count', 
        'class_2_count', 'class_3_count', 'class_4_count', 'class_5_count', 
        'class_6_count', 'class_7_count', 'class_8_count', 'class_9_count'
    ]
    
    RARE_CLASSES = [2, 4, 6, 7, 8] 
    CLASS_MAP = {0: "acne", 1: "blackheads", 2: "dark_spots", 3: "dry_skin", 4: "enlarged_pores", 5: "eyebags", 6: "oily_skin", 7: "skin_redness", 8: "whiteheads", 9: "wrinkles"}

    def __init__(self, model_path: str):
        self.model = joblib.load(model_path)
        if isinstance(self.model, list):
            raise TypeError("Model loaded as list. Please check your .pkl file.")

    def calculate_score(self, yolo_result):
        boxes = yolo_result.boxes
        if boxes is None or len(boxes) == 0:
            return {"score": 0.0, "conditions": []}

        # 1. Basic Stats
        cls_ids = boxes.cls.cpu().numpy().astype(int)
        confs = boxes.conf.cpu().numpy()
        xywh = boxes.xywh.cpu().numpy()
        img_h, img_w = yolo_result.orig_shape

        max_conf = float(confs.max())
        mean_conf = float(confs.mean())
        
        # Calculate Total Area 
        total_area = float(((xywh[:, 2] * xywh[:, 3]) / (img_h * img_w)).sum())
        
        # Prepare Feature Data for the ML Model
        data = {
            'num_detections': len(cls_ids),
            'mean_conf': mean_conf,
            'max_conf': max_conf,
            'total_area_capped': min(total_area, 1.5),
            'density': total_area / len(cls_ids),
            'rare_class_count': sum(1 for c in cls_ids if c in self.RARE_CLASSES)
        }
        for i in range(10):
            data[f'class_{i}_count'] = float(np.sum(cls_ids == i))

        X = pd.DataFrame([data])[self.FEATURE_NAMES]
        base_ml_score = float(self.model.predict(X)[0])


        conf_signal = np.sqrt(max_conf) * 50

        area_signal = min(total_area * 100, 25)

 
        model_signal = base_ml_score * 2.5

        # Combine and Apply Weighting
        final_score = conf_signal + area_signal + model_signal

        #  Final Polish
        if max_conf > 0.5 and total_area > 0.1:
            final_score = max(final_score, 50.0)

        final_score = min(max(final_score, 0.0), 100.0)
        detected_conditions = sorted(list(set([self.CLASS_MAP.get(c, "unknown") for c in cls_ids])))

        return {
            "score": round(final_score, 1),
            "conditions": detected_conditions
        }