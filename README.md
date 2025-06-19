# CNN-FPGA-Accelerator
**FPGA-Based Accelerator for MNIST Classifier (CNN Architecture)**

This project implements a Convolutional Neural Network (CNN) on an FPGA to classify handwritten digits from the MNIST dataset.  
The goal is to accelerate inference using custom RTL hardware optimized for minimal latency.  
Rather than focusing on batch processing, our primary target was to minimize the **latency of a single image classification** among the 10,000 MNIST test images.

---

## 🎯 Target Model Architecture

We implemented a lightweight CNN tailored for FPGA deployment.  
The model structure is as follows:

<p align="center">
  <img src="images/target_cnn_architecture.png" alt="CNN Architecture" width="70%">
</p>

To run the model efficiently on FPGA, we used fixed-point arithmetic with an 8-bit representation.  
All intermediate and output values were stored using 8 bits.

To fit values into this limited precision:
- We discarded the lower bits after multiplication to reduce the bit-width.
- Then, we applied clamping to keep the values within the valid 8-bit range.

The diagram below illustrates how this fixed-point quantization process works:

<p align="center">
  <img src="images/bit_precision.png" alt="Fixed-Point Processing" width="70%">
</p>

---

## 📊 Computational Analysis

In this section, we break down the computation cost per layer in terms of:
- Number of **Multiply-Accumulate (MAC)** operations
- Number of **input memory (IMEM)** and **weight memory (WMEM)** accesses

This analysis justifies our decision to adopt different dataflow models:
- **Weight Stationary** vs **Input Stationary** strategies

|           Layer           | Convolution 1 | Convolution 2 | Max Pooling | Fully Connected |
|---------------------------|---------------|---------------|-------------|-----------------|
| IMEM Access               | 784           | 5408          | 9216        | 2304            |
| WMEM Access               | 72            | 1152          | -           | 23040           |
| MAC Operations            | 48672         | 663552        | -           | 23040           |
| Dataflow Strategy         | Weight Stationary | Weight Stationary | - | Output Stationary |

---

## 🧩 Hardware Architecture

> *(Suggested title: “Our Custom RTL Architecture” or “Processing Element-Based Hardware Design”)*

Our design leverages a **PE (Processing Element)-based architecture**, where MAC units are reused across convolution and FC layers.

<!-- PE + MAC diagram side-by-side -->
<p align="center">
  <img src="images/PE_structure.png" width="60%">
  <img src="images/MAC.png" width="30%">
</p>

<p align="center"><i>Left: PE Structure Diagram | Right: MAC Layout</i></p>


hello

<p align="center">
  <img src="images/4PE_structure.png" alt="PE Architecture" width="50%">
</p>

hi

<p align="center">
  <img src="images/weight_distribution.png" width="45%">
  <img src="images/FC_weight_distribution.png" width="45%">
</p>

Each layer performs operations as follows:
- **Convolution 1**: Streaming data into PEs with weight reuse

<p align="center">
  <img src="images/conv1_layer.png" alt="Conv1 Layer" width="70%">
</p>

- **Convolution 2**: Streaming data into PEs with weight reuse

<p align="center">
  <img src="images/conv2_maxpool_layer.png" alt="Conv2+Pooling" width="100%">
</p>

- **Fully Connected**: Executed using the same PE array in time-multiplexed fashion

<p align="center">
  <img src="images/fc_layer.png" alt="FC Layer" width="100%">
</p>

We also carefully designed **BRAM access patterns** to optimize performance.

| Memory Module | Size (KB) | Purpose                      |
|---------------|-----------|------------------------------|
| BRAM 1        | 16        | Input Feature Maps           |
| BRAM 2        | 32        | Weights                      |
| BRAM 3        | 8         | Intermediate/Output Buffers  |

---

## 🔍 Results & Analysis

After full synthesis and implementation on the FPGA board:

<p align="center">
  <img src="images/power_report.png" width="45%">
  <img src="images/resource_report.png" width="45%">
</p>


<p align="center">
  <img src="images/imple_design.png" alt="Implementation Design" width="30%">
</p>

---

## 🔭 Future Work & Extensions

We explored model compression techniques including:
- **Quantization**: down to 4-bit and 2-bit versions  
  We verified the accuracy by comparing against a **Python-based inference (Jupyter Notebook)**.  
  Our 4-bit quantized model retained **~97% accuracy** on MNIST.
- **PE sharing** for further area reduction
- Support for **larger datasets (e.g., CIFAR-10)**

<p align="center">
  <img src="images/qt_4bit.png" alt="Quantization 4bit" width="70%">
</p>

<p align="center">
  <img src="images/qt_2bit.png" alt="Quantization 2bit" width="70%">
</p>

---

## 🛠️ Technologies Used

- Verilog HDL (RTL)
- Xilinx Vivado
- Python (model design, validation)
- Jupyter Notebook (evaluation, visualization)
