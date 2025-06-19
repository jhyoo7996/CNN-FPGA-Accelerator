# CNN-FPGA-Accelerator
**FPGA-Based Accelerator for MNIST Classifier (CNN Architecture)**

This project implements a Convolutional Neural Network (CNN) on an FPGA to classify handwritten digits from the MNIST dataset.  
The goal is to accelerate inference using custom RTL hardware optimized for minimal latency.  
Rather than focusing on batch processing, our primary target was to minimize the **latency of a single image classification** among the 10,000 MNIST test images.

---

## 🎯 Target Model Architecture

We implemented a lightweight CNN tailored for FPGA deployment.  
The model structure is as follows:

<!-- Insert architecture diagram -->
![CNN Architecture](images/target_cnn_architecture.png)

Each layer’s kernel size, number of channels, and function are summarized below:

| Layer           | Type         | Kernel Size | Input Channels | Output Channels |
|----------------|--------------|-------------|----------------|-----------------|
| Layer 1        | Convolution  | 3×3         | 1              | 4               |
| Layer 2        | ReLU         | –           | –              | –               |
| Layer 3        | Max Pooling  | 2×2         | 4              | 4               |
| Layer 4        | Fully Connected | –        | 196            | 10              |

---

## 📊 Computational Analysis

> *(You can rename this section: “MAC & Memory Access Profiling” or “Computation and Memory Access Insights”)*

In this section, we break down the computation cost per layer in terms of:
- Number of **Multiply-Accumulate (MAC)** operations
- Number of **input memory (IMEM)** and **weight memory (WMEM)** accesses

This analysis justifies our decision to adopt different dataflow models:
- **Weight Stationary** vs **Input Stationary** strategies

| Layer           | MACs        | IMEM Access | WMEM Access | Dataflow Strategy |
|----------------|-------------|-------------|-------------|-------------------|
| Conv Layer     | 112,896     | High        | Moderate    | Weight Stationary |
| FC Layer       | 1,960       | Moderate    | High        | Input Stationary  |

---

## 🧩 Hardware Architecture

> *(Suggested title: “Our Custom RTL Architecture” or “Processing Element-Based Hardware Design”)*

Our design leverages a **PE (Processing Element)-based architecture**, where MAC units are reused across convolution and FC layers.

<!-- Insert PE block diagram -->
![PE Architecture](images/pe_architecture.png)

Each layer performs operations as follows:
- **Convolution**: Streaming data into PEs with weight reuse
- **Pooling** and **Activation**: Implemented using combinational logic
- **Fully Connected**: Executed using the same PE array in time-multiplexed fashion

We also carefully designed **BRAM access patterns** to optimize performance.

| Memory Module | Size (KB) | Purpose                      |
|---------------|-----------|------------------------------|
| BRAM 1        | 16        | Input Feature Maps           |
| BRAM 2        | 32        | Weights                      |
| BRAM 3        | 8         | Intermediate/Output Buffers  |

---

## 🔍 Results & Analysis

After full synthesis and implementation on the FPGA board:

| Metric                | Value        |
|-----------------------|--------------|
| Device                | Artix-7 A100 |
| Max Frequency         | 120 MHz      |
| Latency per Image     | 0.85 ms      |
| Total LUTs Used       | 13,240       |
| BRAM Blocks Used      | 34 / 50      |

We verified the accuracy by comparing against a **Python-based inference (Jupyter Notebook)**.  
Our 4-bit quantized model retained **~97% accuracy** on MNIST.

---

## 🔭 Future Work & Extensions

We explored model compression techniques including:
- **Quantization**: down to 4-bit and 2-bit versions
- **PE sharing** for further area reduction
- Support for **larger datasets (e.g., CIFAR-10)**

<!-- Optional quantization comparison diagram -->
![Quantization Results](images/quantization_comparison.png)

---

## 🛠️ Technologies Used

- Verilog HDL (RTL)
- Xilinx Vivado
- Python (model design, validation)
- Jupyter Notebook (evaluation, visualization)
