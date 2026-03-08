import cv2
import torch
import numpy as np
from PIL import Image
from transformers import SegformerImageProcessor, AutoModelForSemanticSegmentation

# 1. Class Map for this specific model
CLASS_MAP = {
    4: "Upper-clothes",
    5: "Skirt",
    6: "Pants",
    7: "Dress",
    8: "Belt",
    9: "Left-shoe",
    10: "Right-shoe",
    12: "Outerwear"
}

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model_name = "mattmdjaga/segformer_b2_clothes"
processor = SegformerImageProcessor.from_pretrained(model_name)
model = AutoModelForSemanticSegmentation.from_pretrained(model_name).to(device)

def get_dominant_color(image_roi):
    """Calculates the average BGR color of a region."""
    pixels = image_roi.reshape(-1, 3)
    # Filter out black pixels (which are the background in our masked ROI)
    pixels = pixels[np.any(pixels != [0, 0, 0], axis=1)]
    if len(pixels) == 0: return (255, 255, 255)
    
    avg_color = pixels.mean(axis=0)
    return tuple(map(int, avg_color))

cap = cv2.VideoCapture(0)

while True:
    ret, frame = cap.read()
    if not ret: break

    # Inference logic
    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    inputs = processor(images=Image.fromarray(rgb_frame), return_tensors="pt").to(device)
    
    with torch.no_grad():
        outputs = model(**inputs)
        upsampled_logits = torch.nn.functional.interpolate(
            outputs.logits.cpu(), size=frame.shape[:2], mode='bilinear'
        )
        pred_seg = upsampled_logits.argmax(dim=1)[0].numpy()

    # Create a fresh display frame
    display_frame = frame.copy()

    for class_id, class_name in CLASS_MAP.items():
        # Create a mask for just THIS specific garment type
        mask = (pred_seg == class_id).astype(np.uint8) * 255
        
        if np.any(mask):
            # 2. COLOR EXTRACTION: Apply mask to original frame to get ONLY the garment pixels
            garment_pixels = cv2.bitwise_and(frame, frame, mask=mask)
            bgr_color = get_dominant_color(garment_pixels)
            
            # Find the coordinates to place the text (centroid of the mask)
            coords = cv2.findNonZero(mask)
            if coords is not None:
                x, y, w, h = cv2.boundingRect(coords)
                
                # 3. TEXT DISPLAY
                label = f"{class_name}"
                # Draw a little color indicator box and text
                cv2.rectangle(display_frame, (x, y-30), (x+150, y), (0,0,0), -1)
                cv2.putText(display_frame, label, (x+5, y-10), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255,255,255), 2)
                # Draw a small circle of the actual detected color
                cv2.circle(display_frame, (x-15, y-15), 10, bgr_color, -1)
                cv2.circle(display_frame, (x-15, y-15), 10, (255,255,255), 1)

    cv2.imshow('Gatorlator: Type & Color Detection', display_frame)
    if cv2.waitKey(1) & 0xFF == ord('q'): break

cap.release()
cv2.destroyAllWindows()