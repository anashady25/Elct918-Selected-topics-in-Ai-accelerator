import numpy as np
import matplotlib.pyplot as plt

def simulate_sparsity_speedup():
    N = 1000  # Number of MAC operations per run
    sparsities = np.arange(0.0, 0.95, 0.05)
    
    dense_cycles_list = []
    sparse_cycles_list = []
    speedups = []
    
    for S in sparsities:
        # Generate random inputs and apply sparsity mask
        iacts = np.random.rand(N)
        weights = np.random.rand(N)
        
        iacts[np.random.rand(N) < S] = 0
        weights[np.random.rand(N) < S] = 0
        
        # 1. Exact Match Metric (Matrix-Vector Product)
        # Standard numpy baseline product
        baseline_psum = np.dot(iacts, weights)
        
        # 2. Cycle Counting
        # Dense Baseline: Processes every element regardless of value
        # Cycles = Total elements + pipeline delay (3)
        dense_cycles = N + 3 
        
        # Eyeriss v2 (CSC): Skips cycles where iact OR weight is zero
        # The PE only spends cycles on aligned non-zero pairs
        non_zero_pairs = np.sum((iacts != 0) & (weights != 0))
        # Cycles = Non-zero pairs + pipeline delay (3)
        sparse_cycles = non_zero_pairs + 3
        
        # In a real Eyeriss v2 SIMD MAC, processing is halved if both weights are non-zero,
        # but for a flattened cycle analysis, we track the scalar non-zero intersections.
        if sparse_cycles == 3:  # Prevent division by zero at extreme sparsity
            sparse_cycles = 4
            
        speedup = dense_cycles / sparse_cycles
        
        dense_cycles_list.append(dense_cycles)
        sparse_cycles_list.append(sparse_cycles)
        speedups.append(speedup)

    # 3. Plotting
    plt.figure(figsize=(8, 5))
    plt.plot(sparsities * 100, speedups, marker='o', color='b', linewidth=2)
    plt.title('Eyeriss v2 PE Speedup vs. Data Sparsity')
    plt.xlabel('Sparsity (%)')
    plt.ylabel('Speedup Factor (Dense Cycles / Sparse Cycles)')
    plt.grid(True)
    plt.show()

if __name__ == "__main__":
    simulate_sparsity_speedup()