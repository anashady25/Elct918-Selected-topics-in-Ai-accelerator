import time
import cv2
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from PIL import Image, ImageDraw, ImageFont

ARABIC_GLYPHS = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩']

class LeNet5MADBase(nn.Module):
    def __init__(self, num_classes: int = 10):
        super().__init__()
        self.conv1 = nn.Conv2d(1, 6, kernel_size=5)
        self.pool1 = nn.AvgPool2d(2, 2)
        self.conv2 = nn.Conv2d(6, 16, kernel_size=5)
        self.pool2 = nn.AvgPool2d(2, 2)
        self.fc1 = nn.Linear(16 * 5 * 5, 120)
        self.fc2 = nn.Linear(120, 84)
        self.fc3 = nn.Linear(84, num_classes)

    def forward(self, x):
        x = torch.tanh(self.conv1(x))
        x = self.pool1(x)
        x = torch.tanh(self.conv2(x))
        x = self.pool2(x)
        x = x.view(x.size(0), -1)
        x = torch.tanh(self.fc1(x))
        x = torch.tanh(self.fc2(x))
        return self.fc3(x)

def preprocess_arabic(roi: np.ndarray):
    """
    Preprocesses ROI with dedicated handling for the Arabic-Indic zero dot (٠).
    """
    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    _, thresh = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    if contours:
        # Lower noise threshold to preserve small dots (Arabic zero)
        valid_contours = [c for c in contours if cv2.contourArea(c) > 5]
        if valid_contours:
            c = max(valid_contours, key=cv2.contourArea)
            x, y, w, h = cv2.boundingRect(c)
            crop = thresh[y:y+h, x:x+w]
        else:
            crop = thresh
            w, h = 20, 20
    else:
        crop = thresh
        w, h = 20, 20

    # ── DOT ZERO (٠) SCALING SPECIAL HANDLING ───────────────────────────────
    # If the bounding box is small in both dimensions, scale conservatively 
    # to maintain its dot identity rather than blowing it up to 20px.
    max_dim = max(w, h)
    if max_dim < 12:  # Dot zero detection threshold
        new_w, new_h = max(3, w), max(3, h)
    else:
        if h > w:
            new_h, new_w = 20, max(1, int(w * (20.0 / h)))
        else:
            new_h, new_w = max(1, int(h * (20.0 / w))), 20

    resized = cv2.resize(crop, (new_w, new_h), interpolation=cv2.INTER_AREA)

    # Center in 28x28 frame and pad to 32x32
    canvas28 = np.zeros((28, 28), dtype=np.uint8)
    start_x, start_y = (28 - new_w) // 2, (28 - new_h) // 2
    canvas28[start_y:start_y+new_h, start_x:start_x+new_w] = resized
    padded32 = np.pad(canvas28, pad_width=2, mode='constant', constant_values=0)

    # Normalize
    tensor = torch.from_numpy(padded32).float() / 255.0
    tensor = (tensor - 0.1307) / 0.3081
    return tensor.unsqueeze(0).unsqueeze(0), padded32

def draw_arabic_text(img, text, position, font_size=28, color=(0, 255, 0)):
    """Helper to render Arabic UTF-8 text cleanly using PIL."""
    img_pil = Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
    draw = ImageDraw.Draw(img_pil)
    try:
        font = ImageFont.truetype("arial.ttf", font_size)
    except IOError:
        font = ImageFont.load_default()
    draw.text(position, text, font=font, fill=color)
    return cv2.cvtColor(np.array(img_pil), cv2.COLOR_RGB2BGR)

def main():
    # 1. Setup Device & Load Model
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"[*] Using device: {device}")

    model = LeNet5MADBase().to(device)
    try:
        model.load_state_dict(torch.load("lenet5_madbase.pt", map_location=device, weights_only=True))
        print("[*] Loaded 'lenet5_madbase.pt' successfully.")
    except FileNotFoundError:
        print("[!] Error: Weights 'lenet5_madbase.pt' not found. Run Task 1 training script first.")
        return

    model.eval()

    # 2. Initialize Webcam
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("[!] Error: Could not open the webcam.")
        return

    box_size = 250
    prev_time = time.time()

    print("[*] Starting camera feed. Press 'q' to quit.")

    try:
        # 3. Main Inference Loop
        while True:
            ret, frame = cap.read()
            if not ret:
                print("[!] Failed to grab frame.")
                break

            # Flip the frame horizontally immediately to fix the mirror effect
            frame = cv2.flip(frame, 1)

            # Calculate Region of Interest (ROI) box coordinates
            h_f, w_f = frame.shape[:2]
            tl_x, tl_y = (w_f - box_size) // 2, (h_f - box_size) // 2
            br_x, br_y = tl_x + box_size, tl_y + box_size

            # Extract ROI and preprocess for the model
            roi = frame[tl_y:br_y, tl_x:br_x]
            input_tensor, model_view_img = preprocess_arabic(roi)
            input_tensor = input_tensor.to(device)

            # 4. Model Prediction
            with torch.no_grad():
                logits = model(input_tensor)
                probs = F.softmax(logits, dim=1)
                conf, pred_class = torch.max(probs, dim=1)
                
                pred_idx = pred_class.item()
                conf_val = conf.item() * 100.0

            arabic_char = ARABIC_GLYPHS[pred_idx]

            # 5. FPS Calculation
            current_time = time.time()
            fps = 1.0 / (current_time - prev_time + 1e-6)
            prev_time = current_time

            # 6. UI Overlay & Graphics
            cv2.rectangle(frame, (tl_x, tl_y), (br_x, br_y), (0, 255, 0), 2)
            cv2.putText(frame, f"FPS: {fps:.1f}", (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 0), 2)
            
            display_str = f"Pred: {pred_idx} [{arabic_char}] ({conf_val:.1f}%)"
            frame = draw_arabic_text(frame, display_str, (tl_x, tl_y - 45), font_size=26, color=(0, 255, 0))

            # 7. Model Input Window (Enlarged)
            model_view_enlarged = cv2.resize(model_view_img, (280, 280), interpolation=cv2.INTER_NEAREST)
            model_view_colored = cv2.cvtColor(model_view_enlarged, cv2.COLOR_GRAY2BGR)
            model_view_colored = draw_arabic_text(
                model_view_colored, 
                f"Input -> Digit: {arabic_char}", 
                (10, 20), font_size=24, color=(0, 255, 0)
            )

            # 8. Display Windows
            cv2.imshow("Arabic-Indic Real-time Recognition", frame)
            cv2.imshow("Model View (32x32 Enlarged)", model_view_colored)

            # 9. Exit Trigger (Crucial: Required for OpenCV to render windows)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                print("[*] Exit key 'q' pressed. Quitting...")
                break

    except KeyboardInterrupt:
        print("\n[*] Interrupted by user.")
        
    finally:
        # 10. Safe Cleanup Sequence
        cap.release()
        cv2.destroyAllWindows()
        print("[*] Camera released and windows closed.")
if __name__ == "__main__":
    main()