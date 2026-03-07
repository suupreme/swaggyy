import cv2
import torch
import numpy as np
from PIL import Image
from transformers import AutoImageProcessor, AutoModelForObjectDetection

# 1. Setup Model & Device
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Testing on: {device}")

CHECKPOINT = "yainage90/fashion-object-detection"
processor = AutoImageProcessor.from_pretrained(CHECKPOINT)
model = AutoModelForObjectDetection.from_pretrained(CHECKPOINT).to(device)

def enhance_lighting_cv2(frame):
    lab = cv2.cvtColor(frame, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    cl = clahe.apply(l)
    return cv2.cvtColor(cv2.merge((cl, a, b)), cv2.COLOR_LAB2BGR)

def get_dominant_color_cv2(frame, box):
    height, width = frame.shape[:2]
    xmin, ymin, xmax, ymax = map(int, box)
    xmin, ymin = max(0, xmin), max(0, ymin)
    xmax, ymax = min(width, xmax), min(height, ymax)
    
    if xmax <= xmin or ymax <= ymin: return (0, 0, 0)
    
    crop = frame[ymin:ymax, xmin:xmax]
    if crop.size == 0: return (0, 0, 0)
    
    avg_color = crop.mean(axis=(0, 1))
    return tuple(int(c) for c in avg_color)

# 2. Start Live Stream
cap = cv2.VideoCapture(0)

print("Press 'q' to stop the test.")

while True:
    ret, frame = cap.read()
    if not ret: break

    # Enhance for the model's benefit
    enhanced_frame = enhance_lighting_cv2(frame)
    pil_img = Image.fromarray(cv2.cvtColor(enhanced_frame, cv2.COLOR_BGR2RGB))
    
    # Inference
    inputs = processor(images=pil_img, return_tensors="pt").to(device)
    with torch.no_grad():
        outputs = model(**inputs)
    
    target_sizes = torch.tensor([[frame.shape[0], frame.shape[1]]])
    results = processor.post_process_object_detection(outputs, threshold=0.5, target_sizes=target_sizes)[0]

    # 3. Visualization
    for score, label, box in zip(results["scores"], results["labels"], results["boxes"]):
        box_list = box.tolist()
        xmin, ymin, xmax, ymax = map(int, box_list)
        
        # Color Extraction
        bgr_color = get_dominant_color_cv2(enhanced_frame, box_list)
        label_name = model.config.id2label[label.item()]
        
        # UI: Draw Box and a small color indicator
        cv2.rectangle(frame, (xmin, ymin), (xmax, ymax), bgr_color, 3)
        
        # Create a background for the text to make it readable
        text = f"{label_name} {int(score*100)}% | RGB:({bgr_color[2]},{bgr_color[1]},{bgr_color[0]})"
        cv2.rectangle(frame, (xmin, ymin-25), (xmin + 350, ymin), bgr_color, -1)
        cv2.putText(frame, text, (xmin + 5, ymin - 7), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

    cv2.imshow('Fashion AI Live Test', frame)
    if cv2.waitKey(1) & 0xFF == ord('q'): break

cap.release()
cv2.destroyAllWindows()