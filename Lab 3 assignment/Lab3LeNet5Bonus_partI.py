import os
import time
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

from datasets import load_dataset 
import torch
import torch.nn as nn
import torch.optim as optim
import torchvision.transforms as transforms
from torch.utils.data import DataLoader, Dataset

print(f"PyTorch version : {torch.__version__}")
print(f"CUDA available  : {torch.cuda.is_available()}")
DEVICE = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"Training device : {DEVICE}")

SEED = 42
torch.manual_seed(SEED)
if torch.cuda.is_available():
    torch.cuda.manual_seed_all(SEED)
torch.backends.cudnn.deterministic = True
torch.backends.cudnn.benchmark = False
print(f"Random seed fixed to {SEED}")

# ── 0. Arabic-Indic Mapping & File Paths ──────────────────────────────────────
ARABIC_GLYPHS = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩']

# Update these paths if your downloaded CSVs are located elsewhere
TRAIN_IMG_PATH = r"C:\Users\abdel\python\csvTrainImages 60k x 784.csv"
TRAIN_LBL_PATH = r"C:\Users\abdel\python\csvTrainLabel 60k x 1.csv"
TEST_IMG_PATH  = r"C:\Users\abdel\python\csvTestImages 10k x 784.csv"
TEST_LBL_PATH  = r"C:\Users\abdel\python\csvTestLabel 10k x 1.csv"
# ── 1. Model Architecture ─────────────────────────────────────────────────────
class LeNet5MADBase(nn.Module):
    """
    LeNet-5 adapted for MADBase (Arabic-Indic MNIST format).
    Accepts 1-channel, 32×32 inputs.
    """
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
        return self.fc3(x)

model = LeNet5MADBase(num_classes=10).to(DEVICE)
total_params = sum(p.numel() for p in model.parameters())
trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)

# ── 2. MADBase Custom Dataset & Loading ───────────────────────────────────────
class MADBaseHFDataset(Dataset):
    def __init__(self, split='train', transform=None):
        # Automatically downloads and caches the dataset from Hugging Face
        print(f"[*] Fetching MADBase '{split}' dataset...")
        self.data = load_dataset("MagedSaeed/MADBase", split=split)
        self.transform = transform

    def __len__(self):
        return len(self.data)

    def __getitem__(self, idx):
        item = self.data[idx]
        img = item['image']   # Hugging Face provides a standard PIL Image
        label = item['label']
        
        if self.transform:
            img = self.transform(img)
            
        return img, label

# ── 3. Data Transformations & Loaders ─────────────────────────────────────────
MNIST_MEAN = (0.1307,)
MNIST_STD  = (0.3081,)
BATCH_SIZE = 128

# Re-added ToTensor() since the dataset now yields standard PIL images
transform_train = transforms.Compose([
    transforms.ToTensor(),
    transforms.Pad(2),                              
    transforms.RandomAffine(degrees=10, translate=(0.1, 0.1)),
    transforms.Normalize(MNIST_MEAN, MNIST_STD),
])

transform_test = transforms.Compose([
    transforms.ToTensor(),
    transforms.Pad(2),                             
    transforms.Normalize(MNIST_MEAN, MNIST_STD),
])

train_dataset = MADBaseHFDataset(split='train', transform=transform_train)
test_dataset  = MADBaseHFDataset(split='test', transform=transform_test)

train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True,  num_workers=0)
test_loader  = DataLoader(test_dataset,  batch_size=BATCH_SIZE, shuffle=False, num_workers=0)

print(f"Training samples : {len(train_dataset):,}")
print(f"Test samples     : {len(test_dataset):,}")
print(f"Batches/epoch    : {len(train_loader)}")

# ── 4. Visualization ──────────────────────────────────────────────────────────
images, labels = next(iter(train_loader))
fig, axes = plt.subplots(2, 8, figsize=(14, 5))
for ax, img, lbl in zip(axes.flat, images[:16], labels[:16]):
    img_disp = img.squeeze().numpy() * MNIST_STD[0] + MNIST_MEAN[0]
    ax.imshow(img_disp, cmap='gray')
    
    # Title includes both Western Integer and Arabic-Indic Glyph
    arabic_glyph = ARABIC_GLYPHS[lbl.item()]
    ax.set_title(f"Label: {lbl.item()} ({arabic_glyph})", fontsize=12)
    ax.axis('off')
    
plt.suptitle('MADBase Training Images (Correct Orientation & Labels)', y=1.02, fontsize=14, fontweight='bold')
plt.tight_layout()
plt.savefig('sample_madbase_batch.png', dpi=100, bbox_inches='tight')
plt.show()

# ── 5. Training Loop ──────────────────────────────────────────────────────────
EPOCHS        = 20
LEARNING_RATE = 0.001

criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min', factor=0.5, patience=3)

def evaluate(loader):
    model.eval()
    correct, total = 0, 0
    with torch.no_grad():
        for inputs, targets in loader:
            inputs, targets = inputs.to(DEVICE), targets.to(DEVICE)
            outputs = model(inputs)
            _, predicted = outputs.max(1)
            total   += targets.size(0)
            correct += predicted.eq(targets).sum().item()
    return 100.0 * correct / total

history = {'train_loss': [], 'train_acc': [], 'test_acc': [], 'epoch_time': []}
print(f"\n{'Epoch':>5} | {'Train Loss':>10} | {'Train Acc':>9} | {'Test Acc':>8} | {'Time (s)':>8}")
print("-" * 55)

for epoch in range(1, EPOCHS + 1):
    model.train()
    running_loss, correct, total = 0.0, 0, 0
    t0 = time.time()

    for inputs, targets in train_loader:
        inputs, targets = inputs.to(DEVICE), targets.to(DEVICE)
        optimizer.zero_grad()
        outputs = model(inputs)
        loss = criterion(outputs, targets)
        loss.backward()
        optimizer.step()

        running_loss += loss.item() * inputs.size(0)
        _, predicted  = outputs.max(1)
        total        += targets.size(0)
        correct      += predicted.eq(targets).sum().item()

    epoch_time = time.time() - t0
    train_loss = running_loss / total
    train_acc  = 100.0 * correct / total
    test_acc   = evaluate(test_loader)

    scheduler.step(train_loss)
    history['train_loss'].append(train_loss)
    history['train_acc'].append(train_acc)
    history['test_acc'].append(test_acc)
    history['epoch_time'].append(epoch_time)

    print(f"{epoch:>5} | {train_loss:>10.4f} | {train_acc:>8.2f}% | {test_acc:>7.2f}% | {epoch_time:>7.1f}s")

avg_epoch_time = sum(history['epoch_time']) / EPOCHS
final_test_acc = evaluate(test_loader)

# ── 6. Metrics & Plots ────────────────────────────────────────────────────────
print("="*45)
print("       MADBASE ARABIC-INDIC REPORT")
print("="*45)
print(f" Architecture     : LeNet-5 (MADBase)")
print(f" Trainable params : {trainable_params:,}")
print(f" Final test acc   : {final_test_acc:.2f}%")
print(f" Best test acc    : {max(history['test_acc']):.2f}%")
print("="*45)

epochs_range = range(1, EPOCHS + 1)
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4))

ax1.plot(epochs_range, history['train_loss'], marker='o', label='Train Loss')
ax1.set_xlabel('Epoch')
ax1.set_ylabel('Cross-Entropy Loss')
ax1.set_title('Training Loss')
ax1.legend()
ax1.grid(True, alpha=0.3)

ax2.plot(epochs_range, history['train_acc'], marker='o', label='Train Acc')
ax2.plot(epochs_range, history['test_acc'],  marker='s', label='Test Acc')
ax2.set_xlabel('Epoch')
ax2.set_ylabel('Accuracy (%)')
ax2.set_title('Accuracy')
ax2.legend()
ax2.grid(True, alpha=0.3)

plt.suptitle('LeNet-5 on MADBase – Training Curves', fontsize=13, fontweight='bold')
plt.tight_layout()
plt.savefig('madbase_training_curves.png', dpi=120, bbox_inches='tight')
plt.show()

# ── 7. Save & Verify Weights ──────────────────────────────────────────────────
WEIGHTS_PATH = 'lenet5_madbase.pt'
torch.save(model.state_dict(), WEIGHTS_PATH)
print(f'Weights saved to: {WEIGHTS_PATH}')

try:
    from google.colab import files
    files.download(WEIGHTS_PATH)
except ImportError:
    pass

model_reload = LeNet5MADBase(num_classes=10).to(DEVICE)
model_reload.load_state_dict(torch.load(WEIGHTS_PATH, map_location=DEVICE, weights_only=True))

model_reload.eval()
correct, total = 0, 0
with torch.no_grad():
    for inputs, targets in test_loader:
        inputs, targets = inputs.to(DEVICE), targets.to(DEVICE)
        outputs = model_reload(inputs)
        _, predicted = outputs.max(1)
        total   += targets.size(0)
        correct += predicted.eq(targets).sum().item()
        
reload_acc = 100.0 * correct / total
print(f'Reload verification accuracy: {reload_acc:.2f}%')
assert abs(reload_acc - final_test_acc) < 0.01, 'Mismatch after reload!'
print('✓ MADBase Weights loaded and verified successfully.')