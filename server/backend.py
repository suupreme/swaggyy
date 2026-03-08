from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import torch
from transformers import AutoImageProcessor, AutoModelForObjectDetection # Removed AutoModelForImageSegmentation
from PIL import Image
import io
import uvicorn
import numpy as np
import cv2
import colorsys
from sklearn.cluster import KMeans
# from torchvision.transforms.functional import normalize # Removed normalize

app = FastAPI()

# Add CORS middleware to allow all origins during development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

# Load models and processor globally
device = "cuda" if torch.cuda.is_available() else "cpu"
CHECKPOINT_OBJECT_DETECTION = "yainage90/fashion-object-detection" # Renamed for clarity
# CHECKPOINT_BACKGROUND_REMOVAL = "briaai/RMBG-1.4" # Removed new checkpoint

print(f"Loading object detection model to {device}...")
processor = AutoImageProcessor.from_pretrained(CHECKPOINT_OBJECT_DETECTION)
model = AutoModelForObjectDetection.from_pretrained(CHECKPOINT_OBJECT_DETECTION).to(device)

# Removed background removal model loading and function
# print(f"Loading background removal model to {device}...")
# rmbg_model = AutoModelForImageSegmentation.from_pretrained(CHECKPOINT_BACKGROUND_REMOVAL, trust_remote_code=True)
# rmbg_model.to(device)
# rmbg_model.eval() # Set to evaluation mode

# Removed Function to remove background
# def remove_background(pil_image):
#     orig_im = pil_image.convert("RGB") # Ensure RGB
#     w, h = orig_im.size
    
#     image = orig_im.resize((1024, 1024), Image.BILINEAR) # Resize to 1024x1024 for RMBG model
#     im_np = np.array(image) / 255.0
#     im_tensor = torch.tensor(im_np, dtype=torch.float32).permute(2, 0, 1).unsqueeze(0)
#     im_tensor = normalize(im_tensor, [0.5, 0.5, 0.5], [1.0, 1.0, 1.0]).to(device)

#     with torch.no_grad():
#         result = rmbg_model(im_tensor)
    
#     # Post-process mask
#     result = torch.nn.functional.interpolate(result[0][0].unsqueeze(0), size=(h, w), mode='bilinear', align_corners=False).squeeze(0)
#     result = (result - result.min()) / (result.max() - result.min())
#     mask = (result * 255).cpu().data.numpy().astype(np.uint8)
    
#     mask_pil = Image.fromarray(mask)
    
#     # Create an RGBA image where background is transparent
#     no_bg_image = Image.new("RGBA", orig_im.size, (0,0,0,0))
#     no_bg_image.paste(orig_im, mask=mask_pil)
    
#     return no_bg_image

@app.post("/detect")
async def detect_fashion(file: UploadFile = File(...)):
    try:
        # 1. Read and validate image
        content = await file.read()
        image = Image.open(io.BytesIO(content)).convert("RGB")
        
        # 2. Remove background from the image (THIS STEP IS SKIPPED AS PER USER'S REQUEST TO STICK WITH OG MODEL)
        # processed_image = remove_background(image)
        # Use original image for inference
        processed_image = image 
        
        # 3. Run Inference on the image (original image as per user's request)
        inputs = processor(images=processed_image, return_tensors="pt").to(device) # Original image for object detection
        with torch.no_grad():
            outputs = model(**inputs)
        
        # 4. Post-process
        target_sizes = torch.tensor([[processed_image.size[1], processed_image.size[0]]])
        results = processor.post_process_object_detection(
            outputs, threshold=0.4, target_sizes=target_sizes
        )[0]
        
        # 5. Format Results
        detections = []
        for score, label, box in zip(results["scores"], results["labels"], results["boxes"]):
            # Get dominant color from the original image (or processed_image if appropriate)
            color_rgb = get_dominant_color(image, box.tolist()) 
            detections.append({
                "label": model.config.id2label[label.item()],
                "confidence": round(score.item(), 3),
                "box": [round(i, 2) for i in box.tolist()],
                "color": color_rgb,
                "complementary_color": get_complementary_recommendation(color_rgb)
            })
        
        print(f"Generated detections: {detections}") # Added debug log
        return {"detections": detections}
    except Exception as e:
        print(f"Internal Error: {e}")
        return {"detections": [], "error": str(e)}

if __name__ == "__main__":
    # Runs on all interfaces (needed for emulator/local network)
    uvicorn.run(app, host="0.0.0.0", port=8000)

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
        
        # Convert PIL Image to NumPy array for color processing
        img_array = np.array(crop)
        
        if img_array.size == 0:
            return [0, 0, 0]
            
        # Convert RGB image array to OpenCV BGR for YCrCb conversion
        img_bgr = cv2.cvtColor(img_array, cv2.COLOR_RGB2BGR)
        img_ycrcb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2YCrCb)

        # Define YCrCb skin color range
        lower_skin = np.array([0, 133, 77], dtype=np.uint8)
        upper_skin = np.array([255, 173, 127], dtype=np.uint8)

        # Create a mask for non-skin pixels
        skin_mask = cv2.inRange(img_ycrcb, lower_skin, upper_skin)
        non_skin_mask = cv2.bitwise_not(skin_mask)

        # Apply the non-skin mask to the original RGB pixels
        pixels = img_array.reshape(-1, 3)
        non_skin_pixels_flat_mask = non_skin_mask.flatten()
        
        non_skin_pixels = pixels[non_skin_pixels_flat_mask == 255]
        
        if non_skin_pixels.size == 0:
            return [0, 0, 0] # Return black if no non-skin pixels found

        # Apply K-Means clustering to find the dominant color among non-skin pixels
        kmeans = KMeans(n_clusters=3, random_state=0, n_init=10) # Reverted n_clusters to 3
        kmeans.fit(non_skin_pixels)
        
        # Find the largest cluster and its color
        counts = np.bincount(kmeans.labels_)
        dominant_cluster_index = np.argmax(counts)
        dominant_color = kmeans.cluster_centers_[dominant_cluster_index]
        
        return [int(c) for c in dominant_color]
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

def get_complementary_recommendation(rgb_tuple):
    # 1. Normalize RGB to 0-1 range
    r, g, b = [x/255.0 for x in rgb_tuple]
    
    # 2. Convert to HSL
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    
    # 3. Rotate Hue by 180 degrees (0.5 in 0-1 scale)
    h_comp = (h + 0.5) % 1.0
    
    # 4. Convert back to RGB to show the user
    r_c, g_c, b_c = colorsys.hls_to_rgb(h_comp, l, s)
    complement_rgb = (int(r_c*255), int(g_c*255), int(b_c*255))
    
    return complement_rgb