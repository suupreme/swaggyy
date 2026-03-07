import io
import uvicorn
from fastapi import FastAPI, File, UploadFile
from PIL import Image
import torch
from transformers import AutoImageProcessor, AutoModelForObjectDetection
import numpy as np
import cv2

app = FastAPI()

# Load model and processor globally
device = "cuda" if torch.cuda.is_available() else "cpu"
CHECKPOINT = "yainage90/fashion-object-detection"

print(f"Loading model to {device}...")
processor = AutoImageProcessor.from_pretrained(CHECKPOINT)
model = AutoModelForObjectDetection.from_pretrained(CHECKPOINT).to(device)

def get_dominant_color(image, box):
    try:
        # 1. Ensure coordinates are within image bounds to prevent crash
        width, height = image.size
        xmin = max(0, int(box[0]))
        ymin = max(0, int(box[1]))
        xmax = min(width, int(box[2]))
        ymax = min(height, int(box[3]))
        
        if xmax <= xmin or ymax <= ymin:
            return [0, 0, 0]

        crop = image.crop((xmin, ymin, xmax, ymax))
        img_array = np.array(crop)
        
        if img_array.size == 0:
            return [0, 0, 0]
            
        avg_color = img_array.mean(axis=(0, 1))
        return [int(c) for c in avg_color]
    except Exception as e:
        print(f"Color error: {e}")
        return [0, 0, 0]

def enhance_lighting(pil_image):
    # 1. Convert PIL to OpenCV (BGR)
    img = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
    
    # 2. Convert to LAB color space (L is for Lightness/Luminance)
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)

    # 3. Apply CLAHE to the L-channel
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8,8))
    cl = clahe.apply(l)

    # 4. Merge channels back and convert to RGB
    limg = cv2.merge((cl, a, b))
    final_img = cv2.cvtColor(limg, cv2.COLOR_LAB2BGR)
    
    return Image.fromarray(cv2.cvtColor(final_img, cv2.COLOR_BGR2RGB))

@app.post("/detect")
async def detect_fashion(file: UploadFile = File(...)):
    try:
        # 1. Read and validate image
        content = await file.read()
        image = enhance_lighting(Image.open(io.BytesIO(content)).convert("RGB"))
        
        # 2. Run Inference
        inputs = processor(images=image, return_tensors="pt").to(device)
        with torch.no_grad():
            outputs = model(**inputs)
        
        # 3. Post-process
        target_sizes = torch.tensor([[image.size[1], image.size[0]]])
        results = processor.post_process_object_detection(
            outputs, threshold=0.4, target_sizes=target_sizes
        )[0]
        
        # 4. Format Results
        detections = []
        for score, label, box in zip(results["scores"], results["labels"], results["boxes"]):
            color_rgb = get_dominant_color(image, box.tolist())
            detections.append({
                "label": model.config.id2label[label.item()],
                "confidence": round(score.item(), 3),
                "box": [round(i, 2) for i in box.tolist()],
                "color": color_rgb
            })
        
        print(f"Detected {len(detections)} items") # Server-side log
        return {"detections": detections}
    except Exception as e:
        print(f"Internal Error: {e}")
        return {"detections": [], "error": str(e)}

if __name__ == "__main__":
    # Runs on all interfaces (needed for emulator/local network)
    uvicorn.run(app, host="0.0.0.0", port=8000)
