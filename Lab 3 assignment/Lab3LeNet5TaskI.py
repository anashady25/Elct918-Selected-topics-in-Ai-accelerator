import time
import torch
import torch.nn as nn
import torch.optim as optim
import torchvision
import torchvision.transforms as transforms
from torch.utils.data import DataLoader

print(f"PyTorch version : {torch.__version__}")
print(f"CUDA available  : {torch.cuda.is_available()}")
DEVICE = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"Training device : {DEVICE}")

SEED = 42
torch.manual_seed(SEED)
if torch.cuda.is_available():
    torch.cuda.manual_seed_all(SEED)
# Make cuDNN deterministic (slight speed cost, worth it for reproducibility)
torch.backends.cudnn.deterministic = True
torch.backends.cudnn.benchmark = False
print(f"Random seed fixed to {SEED}")

class LeNet5MNIST(nn.Module):
    """
    LeNet-5 adapted for MNIST.
    Accepts 1-channel, 32×32 inputs (28×28 MNIST images zero-padded by 2 px each side).
    Spatial flow: 32→28→14→10→5  (identical to the original paper).
    """
    def __init__(self, num_classes: int = 10):
        super().__init__()
        # ── Feature extractor ─────────────────────────────────────────────────
        self.conv1 = nn.Conv2d(1, 6, kernel_size=5)   # 1 channel  ← only change
        self.pool1 = nn.AvgPool2d(kernel_size=2, stride=2)
        self.conv2 = nn.Conv2d(6, 16, kernel_size=5)
        self.pool2 = nn.AvgPool2d(kernel_size=2, stride=2)
        # ── Classifier ────────────────────────────────────────────────────────
        self.fc1 = nn.Linear(16 * 5 * 5, 120)
        self.fc2 = nn.Linear(120, 84)
        self.fc3 = nn.Linear(84, num_classes)

    def forward(self, x):
        x = torch.tanh(self.conv1(x))   # 32→28
        x = self.pool1(x)               # 28→14
        x = torch.tanh(self.conv2(x))   # 14→10
        x = self.pool2(x)               # 10→5
        x = x.view(x.size(0), -1)       # flatten: 16×5×5 = 400
        x = torch.tanh(self.fc1(x))
        x = torch.tanh(self.fc2(x))
        x = self.fc3(x)                 # raw logits
        return x


model = LeNet5MNIST(num_classes=10).to(DEVICE)

# ── Parameter count ──────────────────────────────────────────────────────────
total_params = sum(p.numel() for p in model.parameters())
trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
print(f"Total parameters     : {total_params:,}")
print(f"Trainable parameters : {trainable_params:,}")
print(model)

# ── MNIST canonical statistics ────────────────────────────────────────────────
MNIST_MEAN = (0.1307,)
MNIST_STD  = (0.3081,)

transform_train = transforms.Compose([
    transforms.Pad(2),                              # 28×28 → 32×32
    transforms.RandomAffine(degrees=10,             # mild augmentation
                             translate=(0.1, 0.1)),
    transforms.ToTensor(),
    transforms.Normalize(MNIST_MEAN, MNIST_STD),
])

transform_test = transforms.Compose([
    transforms.Pad(2),                              # 28×28 → 32×32
    transforms.ToTensor(),
    transforms.Normalize(MNIST_MEAN, MNIST_STD),
])

DATA_DIR   = './mnist_data'
BATCH_SIZE = 128

train_dataset = torchvision.datasets.MNIST(root=DATA_DIR, train=True,
                                            download=True, transform=transform_train)
test_dataset  = torchvision.datasets.MNIST(root=DATA_DIR, train=False,
                                            download=True, transform=transform_test)

train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE,
                          shuffle=True,  num_workers=0, pin_memory=False)
test_loader  = DataLoader(test_dataset,  batch_size=BATCH_SIZE,
                          shuffle=False, num_workers=0, pin_memory=False)

print(f"Training samples : {len(train_dataset):,}")
print(f"Test samples     : {len(test_dataset):,}")
print(f"Batches/epoch    : {len(train_loader)}")

import matplotlib.pyplot as plt
import numpy as np

images, labels = next(iter(train_loader))
fig, axes = plt.subplots(2, 8, figsize=(14, 4))
for ax, img, lbl in zip(axes.flat, images[:16], labels[:16]):
    # Un-normalise for display
    img_disp = img.squeeze().numpy() * MNIST_STD[0] + MNIST_MEAN[0]
    ax.imshow(img_disp, cmap='gray')
    ax.set_title(str(lbl.item()))
    ax.axis('off')
plt.suptitle('Sample training images (32×32, normalised and un-normalised for display)', y=1.02)
plt.tight_layout()
plt.savefig('sample_mnist_batch.png', dpi=100, bbox_inches='tight')
plt.show()
print(f"Input tensor shape : {images.shape}   (B, C, H, W)")

EPOCHS        = 15
LEARNING_RATE = 0.001

criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
# Reduce LR when val loss plateaus
scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min',
                                                  factor=0.5, patience=3)

# ── Helper: evaluate on any loader ───────────────────────────────────────────
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


# ── Training loop ─────────────────────────────────────────────────────────────
history = {'train_loss': [], 'train_acc': [], 'test_acc': [], 'epoch_time': []}

print(f"{'Epoch':>5} | {'Train Loss':>10} | {'Train Acc':>9} | {'Test Acc':>8} | {'Time (s)':>8}")
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
print(f"\nAverage time per epoch : {avg_epoch_time:.1f}s")
print(f"Best test accuracy     : {max(history['test_acc']):.2f}%")

final_test_acc = evaluate(test_loader)

print("="*45)
print("       TASK 1 – REPORT METRICS")
print("="*45)
print(f"  Architecture         : LeNet-5 (MNIST)")
print(f"  Total parameters     : {total_params:,}")
print(f"  Trainable parameters : {trainable_params:,}")
print(f"  Epochs trained       : {EPOCHS}")
print(f"  Avg time / epoch     : {avg_epoch_time:.1f} s")
print(f"  Final test accuracy  : {final_test_acc:.2f}%")
print(f"  Best test accuracy   : {max(history['test_acc']):.2f}%")
print(f"  Normalisation mean   : {MNIST_MEAN[0]}")
print(f"  Normalisation std    : {MNIST_STD[0]}")
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

plt.suptitle('LeNet-5 on MNIST – Training Curves', fontsize=13, fontweight='bold')
plt.tight_layout()
plt.savefig('training_curves.png', dpi=120, bbox_inches='tight')
plt.show()
print('Saved training_curves.png')

WEIGHTS_PATH = 'lenet5_mnist.pt'
torch.save(model.state_dict(), WEIGHTS_PATH)
print(f'Weights saved to: {WEIGHTS_PATH}')

# ── Colab: trigger automatic download ─────────────────────────────────────────
try:
    from google.colab import files
    files.download(WEIGHTS_PATH)
    print('Download started – check your browser downloads.')
except ImportError:
    print('Not in Colab – weights saved locally.')

# Reload from disk and confirm accuracy is unchanged
model_reload = LeNet5MNIST(num_classes=10).to(DEVICE)
model_reload.load_state_dict(torch.load(WEIGHTS_PATH, map_location=DEVICE))
reload_acc = evaluate(test_loader)   # evaluate() still references `model` — patch that:

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
print('✓ Weights loaded and verified successfully.')