import time
import cv2
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

# ── 1. Model Architecture (Must match exactly how it was trained) ─────────────
class LeNet5MNIST(nn.Module):
    def __init__(self, num_classes: int = 10):
        super().__init__()
        self.conv1 = nn.Conv2d(1, 6, kernel_size=5)
        self.pool1 = nn.AvgPool2d(kernel_size=2, stride=2)
        self.conv2 = nn.Conv2d(6, 16, kernel_size=5)
        self.pool2 = nn.AvgPool2d(kernel_size=2, stride=2)
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
        x = self.fc3(x)
        return x

# ── 2. Preprocessing Pipeline ────────────────────────────────────────────────
def preprocess(roi: np.ndarray):
    """Converts the camera ROI into a 32x32 tensor for LeNet-5."""
    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)

    # Threshold and invert (black background, white digit)
    _, thresh = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    kernel = np.ones((3, 3), np.uint8)
    thresh = cv2.dilate(thresh, kernel, iterations=1) # Thicken lines

    # Crop the digit
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if contours:
        c = max(contours, key=cv2.contourArea)
        if cv2.contourArea(c) > 30: 
            x, y, w, h = cv2.boundingRect(c)
            crop = thresh[y:y+h, x:x+w]
        else:
            crop = thresh
    else:
        crop = thresh

    # Resize to max 20px, maintaining aspect ratio
    h, w = crop.shape[:2]
    if h > 0 and w > 0:
        if h > w:
            new_h, new_w = 20, max(1, int(w * (20.0 / h)))
        else:
            new_h, new_w = max(1, int(h * (20.0 / w))), 20
        resized = cv2.resize(crop, (new_w, new_h), interpolation=cv2.INTER_AREA)
    else:
        resized = np.zeros((20, 20), dtype=np.uint8)
        new_w, new_h = 20, 20

    # Center in 28x28 and pad to 32x32
    canvas28 = np.zeros((28, 28), dtype=np.uint8)
    start_x, start_y = (28 - new_w) // 2, (28 - new_h) // 2
    canvas28[start_y:start_y+new_h, start_x:start_x+new_w] = resized
    padded32 = np.pad(canvas28, pad_width=2, mode='constant', constant_values=0)

    # Convert to Tensor (1, 1, 32, 32) & Normalize
    tensor = torch.from_numpy(padded32).float() / 255.0
    tensor = (tensor - 0.1307) / 0.3081
    tensor = tensor.unsqueeze(0).unsqueeze(0) 

    return tensor, padded32

# ── 3. Live Camera Inference Loop ────────────────────────────────────────────
def main():
    # 1. Setup Device & Load Model
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"[*] Running inference on: {device}")

    # Load Model Weights
    model = LeNet5MNIST().to(device)
    
    model_path = "lenet5_mnist.pt" 
    
    try:
        model.load_state_dict(torch.load(model_path, map_location=device, weights_only=True))
        print(f"[*] Successfully loaded weights from '{model_path}'")
    except FileNotFoundError:
        print(f"[!] Error: '{model_path}' not found. Make sure it is in the same folder.")
        return

    model.eval()

    # 2. Initialize Webcam
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("[!] Error: Could not open webcam.")
        return

    print("[*] Camera active. Press 'q' in the video window to exit.")

    box_size = 250
    prev_time = time.time()

    try:
        # 3. Main Inference Loop
        while True:
            ret, frame = cap.read()
            if not ret:
                print("[!] Failed to grab frame.")
                break

            # Mirror the entire frame for a natural user experience
            frame = cv2.flip(frame, 1)
            frame_h, frame_w = frame.shape[:2]

            # Define the center bounding box where the user should hold the digit
            top_left_x, top_left_y = (frame_w - box_size) // 2, (frame_h - box_size) // 2
            bottom_right_x, bottom_right_y = top_left_x + box_size, top_left_y + box_size

            # Extract the mirrored ROI from the main frame
            roi = frame[top_left_y:bottom_right_y, top_left_x:bottom_right_x]

            # FLIP THE ROI BACK: Undo the mirror effect so the model reads normally
            roi_for_model = cv2.flip(roi, 1)

            # Preprocess and Predict using the CORRECTED ROI
            input_tensor, model_view_img = preprocess(roi_for_model)
            input_tensor = input_tensor.to(device)

            # 4. Model Prediction
            with torch.no_grad():
                logits = model(input_tensor)
                probabilities = F.softmax(logits, dim=1)
                confidence, pred_class = torch.max(probabilities, dim=1)
                
                predicted_digit = pred_class.item()
                conf_score = confidence.item() * 100.0

            # 5. FPS Calculation
            curr_time = time.time()
            fps = 1.0 / (curr_time - prev_time) if (curr_time - prev_time) > 0 else 0.0
            prev_time = curr_time

            # 6. UI Overlay & Graphics
            cv2.rectangle(frame, (top_left_x, top_left_y), (bottom_right_x, bottom_right_y), (0, 255, 0), 2)
            cv2.putText(frame, f"FPS: {fps:.1f}", (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 0), 2)
            cv2.putText(frame, f"Pred: {predicted_digit}", (top_left_x, top_left_y - 35), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)
            cv2.putText(frame, f"Conf: {conf_score:.1f}%", (top_left_x, top_left_y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)

            # 7. Model Input Window (Shows the corrected orientation the model actually sees)
            model_view_enlarged = cv2.resize(model_view_img, (280, 280), interpolation=cv2.INTER_NEAREST)

            # 8. Display Windows
            cv2.imshow("Live Digit Recognition", frame)
            cv2.imshow("Model Input View (32x32 Enlarged)", model_view_enlarged)

            # 9. Exit Trigger
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