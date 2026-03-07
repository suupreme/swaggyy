import io
from fastapi import FastAPI, File, UploadFile
from PIL import Image
import torch
from transformers import AutoImageProcessor, AutoModelForObjectDetection

app = FastAPI()

# Load model and processor globally so they stay in memory
device = "cuda" if torch.cuda.is_available() else "cpu"
CHECKPOINT = "yainage90/fashion-object-detection"

print(f"Loading model to {device}...")
processor = AutoImageProcessor.from_pretrained(CHECKPOINT)
model = AutoModelForObjectDetection.from_pretrained(CHECKPOINT).to(device)

@app.post("/detect")
async def detect_fashion(file: UploadFile = File(...)):
    # 1. Read the uploaded image
    request_object_content = await file.read()
    image = Image.open(io.BytesIO(request_object_content)).convert("RGB")
    
    # 2. Run Inference
    with torch.no_grad():
        inputs = processor(images=image, return_tensors="pt").to(device)
        outputs = model(**inputs)
    
    # 3. Post-process (Threshold 0.4 as suggested by model card)
    target_sizes = torch.tensor([[image.size[1], image.size[0]]])
    results = processor.post_process_object_detection(
        outputs, threshold=0.4, target_sizes=target_sizes
    )[0]
    
    # 4. Format Results for Flutter
    detections = []
    for score, label, box in zip(results["scores"], results["labels"], results["boxes"]):
        detections.append({
            "label": model.config.id2label[label.item()],
            "confidence": round(score.item(), 3),
            "box": [round(i, 2) for i in box.tolist()] # [xmin, ymin, xmax, ymax]
        })
        
    return {"detections": detections}

if __name__ == "__main__":
    import uvicorn
    # Use 0.0.0.0 to make it accessible over your network/Tailscale
    uvicorn.run(app, host="0.0.0.0", port=8000)