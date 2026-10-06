import cv2
import numpy as np
import torch
import matplotlib.pyplot as plt

def preprocess(roi: np.ndarray, return_intermediate: bool = False):
    """
    Preprocesses a camera frame region of interest (ROI) for LeNet-5.
    
    Steps:
    1. Grayscale & Gaussian Blur
    2. Threshold & Invert (Otsu's method) + Dilation
    3. Crop digit using largest contour bounding box
    4. Resize maintaining aspect ratio (max 20px), center on 28x28, pad to 32x32
    5. Normalize & convert to PyTorch Tensor (1, 1, 32, 32)
    """
    # -------------------------------------------------------------------------
    # Step 1: Grayscale & Gaussian Blur
    # -------------------------------------------------------------------------
    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
    step1_blur = cv2.GaussianBlur(gray, (5, 5), 0)

    # -------------------------------------------------------------------------
    # Step 2: Threshold & Invert (+ Dilation)
    # -------------------------------------------------------------------------
    _, step2_thresh = cv2.threshold(
        step1_blur, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU
    )
    # Optional dilation to thicken stroke width if pen strokes are thin
    kernel = np.ones((3, 3), np.uint8)
    step2_thresh = cv2.dilate(step2_thresh, kernel, iterations=1)

    # -------------------------------------------------------------------------
    # Step 3: Crop the Digit
    # -------------------------------------------------------------------------
    contours, _ = cv2.findContours(
        step2_thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
    )
    
    if contours:
        c = max(contours, key=cv2.contourArea)
        x, y, w, h = cv2.boundingRect(c)
        step3_crop = step2_thresh[y:y+h, x:x+w]
    else:
        step3_crop = step2_thresh.copy()
        x, y, w, h = 0, 0, step2_thresh.shape[1], step2_thresh.shape[0]

    # -------------------------------------------------------------------------
    # Step 4: Resize and Centre (20px box in 28x28 -> pad to 32x32)
    # -------------------------------------------------------------------------
    crop_h, crop_w = step3_crop.shape[:2]
    
    # Scale larger dimension to 20 pixels keeping aspect ratio
    if crop_h > crop_w:
        new_h = 20
        new_w = max(1, int(crop_w * (20.0 / crop_h)))
    else:
        new_w = 20
        new_h = max(1, int(crop_h * (20.0 / crop_w)))
        
    resized_digit = cv2.resize(step3_crop, (new_w, new_h), interpolation=cv2.INTER_AREA)

    # Place in center of 28x28 canvas
    canvas28 = np.zeros((28, 28), dtype=np.uint8)
    start_x = (28 - new_w) // 2
    start_y = (28 - new_h) // 2
    canvas28[start_y:start_y+new_h, start_x:start_x+new_w] = resized_digit

    # Pad 28x28 to 32x32 (2 pixels on all sides)
    step4_padded32 = np.pad(canvas28, pad_width=2, mode='constant', constant_values=0)

    # -------------------------------------------------------------------------
    # Step 5: Convert to PyTorch Tensor & Normalize
    # -------------------------------------------------------------------------
    MNIST_MEAN = 0.1307
    MNIST_STD = 0.3081

    # Scale to [0, 1] float
    tensor_img = torch.from_numpy(step4_padded32).float() / 255.0
    # Apply MNIST canonical normalization
    tensor_img = (tensor_img - MNIST_MEAN) / MNIST_STD
    # Reshape to model layout (Batch, Channel, Height, Width) -> [1, 1, 32, 32]
    step5_tensor = tensor_img.unsqueeze(0).unsqueeze(0)

    if return_intermediate:
        intermediates = {
            "Original ROI": roi,
            "1. Gray & Blur": step1_blur,
            "2. Threshold & Invert": step2_thresh,
            "3. Cropped Digit": step3_crop,
            "4. Resized & Padded (32x32)": step4_padded32,
            "5. Final Tensor Layout": step5_tensor.squeeze().numpy()
        }
        return step5_tensor, intermediates

    return step5_tensor


def generate_deliverable_figure(roi: np.ndarray, save_path: str = "preprocessing_pipeline.png"):
    """
    Executes the preprocessing pipeline and plots a multi-panel figure 
    showing the step-by-step transformations.
    """
    _, steps = preprocess(roi, return_intermediate=True)

    plt.figure(figsize=(15, 3))
    
    for idx, (title, img) in enumerate(steps.items(), 1):
        plt.subplot(1, 6, idx)
        if len(img.shape) == 3:  # BGR Image
            plt.imshow(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
        else:  # Grayscale / Tensor
            plt.imshow(img, cmap='gray')
            
        plt.title(title, fontsize=9)
        plt.axis('off')

    plt.tight_layout()
    plt.savefig(save_path, dpi=300, bbox_inches='tight')
    print(f"[*] Deliverable figure saved to {save_path}")
    plt.show()


# ==========================================
# EXAMPLE USAGE / TEST BENCH
# ==========================================
if __name__ == "__main__":
    # Create a synthetic ROI frame containing a white background with a dark digit '7'
    synthetic_roi = np.ones((150, 150, 3), dtype=np.uint8) * 240
    cv2.putText(synthetic_roi, '7', (35, 110), cv2.FONT_HERSHEY_SIMPLEX, 4, (30, 30, 30), 10)

    # Process & generate figure
    tensor_output, _ = preprocess(synthetic_roi, return_intermediate=True)
    print(f"Output Tensor Shape: {tensor_output.shape}")  # Expects torch.Size([1, 1, 32, 32])
    
    # Generate the deliverable figure
    generate_deliverable_figure(synthetic_roi)