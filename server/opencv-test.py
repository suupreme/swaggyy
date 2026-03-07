import cv2
import torch
from transformers import AutoImageProcessor, AutoModelForObjectDetection
from PIL import Image

# 1. Setup Model
ckpt = 'yainage90/fashion-object-detection'
processor = AutoImageProcessor.from_pretrained(ckpt)
model = AutoModelForObjectDetection.from_pretrained(ckpt)

# 2. Access Webcam
cap = cv2.VideoCapture(0)

# 1. Select the device
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using device: {device}")

# 2. Setup Model and move it to GPU
ckpt = 'yainage90/fashion-object-detection'
processor = AutoImageProcessor.from_pretrained(ckpt)
# Add .to(device) here
model = AutoModelForObjectDetection.from_pretrained(ckpt).to(device)

while True:
    ret, frame = cap.read()
    if not ret: break

    # Convert BGR (OpenCV) to RGB (PIL) for the model
    pil_img = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
    
    # Run Detection
    inputs = processor(images=pil_img, return_tensors="pt").to(device)
    
    with torch.no_grad():
        outputs = model(**inputs)
    
    # Post-process (scale boxes to frame size)
    target_sizes = torch.tensor([[frame.shape[0], frame.shape[1]]])
    results = processor.post_process_object_detection(outputs, threshold=0.5, target_sizes=target_sizes)[0]

    # 3. Draw Overlays (The "Overlay" part)
    for score, label, box in zip(results["scores"], results["labels"], results["boxes"]):
        xmin, ymin, xmax, ymax = map(int, box)
        label_text = f"{model.config.id2label[label.item()]}: {score:.2f}"
        
        # Draw Box
        cv2.rectangle(frame, (xmin, ymin), (xmax, ymax), (0, 255, 0), 2)
        # Draw Label
        cv2.putText(frame, label_text, (xmin, ymin - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)

    cv2.imshow('Fashion Detection Test', frame)
    if cv2.waitKey(1) & 0xFF == ord('q'): break

cap.release()
cv2.destroyAllWindows()