<h1 align='center'>SpatialVID: A Large-Scale Video Dataset with Spatial Annotations</h1>
<div align='center'>
    <a href='https://oiiiwjh.github.io/' target='_blank'>Jiahao Wang</a><sup>1*</sup> 
    <a href='https://github.com/FelixYuan-YF' target='_blank'>Yufeng Yuan</a><sup>1*</sup> 
    <a href='https://zrj-cn.github.io/' target='_blank'>Rujie Zheng</a><sup>1*</sup> 
    <a href='https://linyou.github.io' target='_blank'>Youtian Lin</a><sup>1</sup> 
    <a href='https://ygaojiany.github.io' target='_blank'>Jian Gao</a><sup>1</sup> 
    <a href='https://linzhuo.xyz' target='_blank'>Lin-Zhuo Chen</a><sup>1</sup> 
</div>
<div align='center'>
    <a href='https://openreview.net/profile?id=~yajie_bao5' target='_blank'>Yajie Bao</a><sup>1</sup> 
    <a href='https://github.com/YeeZ93' target='_blank'>Yi Zhang</a><sup>1</sup> 
    <a href='https://github.com/ozchango' target='_blank'>Chang Zeng</a><sup>1</sup> 
    <a href='https://github.com/yxzhou217' target='_blank'>Yanxi Zhou</a><sup>1</sup> 
    <a href='https://www.xxlong.site/index.html' target='_blank'>Xiaoxiao Long</a><sup>1</sup> 
    <a href='http://zhuhao.cc/home/' target='_blank'>Hao Zhu</a><sup>1</sup> 
</div>
<div align='center'>
    <a href='http://zhaoxiangzhang.net/' target='_blank'>Zhaoxiang Zhang</a><sup>2</sup> 
    <a href='https://cite.nju.edu.cn/People/Faculty/20190621/i5054.html' target='_blank'>Xun Cao</a><sup>1</sup> 
    <a href='https://yoyo000.github.io/' target='_blank'>Yao Yao</a><sup>1†</sup>
</div>
<div align='center'>
    <sup>1</sup>Nanjing University  <sup>2</sup>Institute of Automation, Chinese Academy of Science 
</div>
<br>
<div align="center">
  <a href="https://nju-3dv.github.io/projects/SpatialVID/"><img src="https://img.shields.io/static/v1?label=SpatialVID&message=Project&color=purple"></a>  
  <a href="https://arxiv.org/abs/2509.09676"><img src="https://img.shields.io/static/v1?label=Paper&message=Arxiv&color=red&logo=arxiv"></a>  
  <a href="https://github.com/NJU-3DV/spatialVID"><img src="https://img.shields.io/static/v1?label=Code&message=Github&color=blue&logo=github"></a>  
  <a href="https://huggingface.co/SpatialVID"><img src="https://img.shields.io/static/v1?label=Dataset&message=HuggingFace&color=yellow&logo=huggingface"></a>  
  <a href="https://www.modelscope.cn/organization/SpatialVID"><img src="https://img.shields.io/static/v1?label=Dataset&message=ModelScope&color=4285F4"></a>
</div>
<p align="center">
  <img src="assets/overview.png"  height=400>
</p>

## 🎉NEWS
+ [2025.09.29] 🚀 Depth data for the SpatialVID-HQ dataset is now officially available.
+ [2025.09.24] 🤗 Raw metadata access is now available via a [gated HuggingFace dataset](https://huggingface.co/datasets/SpatialVID/SpatialVID-RAW) to better support community research!!
+ [2025.09.24] 🔭 Enhanced instructions for better camera control are updated.
+ [2025.09.18] 🎆 SpatialVID dataset is now available on both HuggingFace and ModelScope.
+ [2025.09.14] 📢 We have also uploaded the SpatialVID-HQ dataset to ModelScope offering more diverse download options.
+ [2025.09.11] 🔥 Our paper, code and SpatialVID-HQ dataset are released!

## Abstract

Significant progress has been made in spatial intelligence, spanning both spatial reconstruction and world exploration. However, the scalability and real-world fidelity of current models remain severely constrained by the scarcity of large-scale, high-quality training data. While several datasets provide camera pose information, they are typically limited in scale, diversity, and annotation richness, particularly for real-world dynamic scenes with ground-truth camera motion. To this end, we collect **SpatialVID**, a dataset consisting of a large corpus of in-the-wild videos with diverse scenes, camera movements and dense 3D annotations such as per-frame camera poses, depth, and motion instructions. Specifically, we collect more than **21,000 hours** of raw videos, and process them into **2.7 million clips** through a hierarchical filtering pipeline, totaling **7,089 hours** of dynamic content. A subsequent annotation pipeline enriches these clips with detailed spatial and semantic information, including camera poses, depth maps, dynamic masks, structured captions, and serialized motion instructions. Analysis of SpatialVID's data statistics reveals a richness and diversity that directly foster improved model generalization and performance, establishing it as a key asset for the video and 3D vision research community.

## Preparation

This section describes how to set up the environment manually. For a simpler, containerized setup, please refer to the **[Docker Setup and Usage](#docker-setup-and-usage)** section.

### Environment

1. Necessary packages

   ```bash
   git clone --recursive https://github.com/NJU-3DV/SpatialVID.git
   cd SpatialVid
   conda create -n SpatialVID python=3.10.13
   conda activate SpatialVID
   pip install -r requirements/requirements.txt
   ```
2. Package needed for scoring

   ```bash
   pip install paddlepaddle-gpu==3.0.0 -i https://www.paddlepaddle.org.cn/packages/stable/cu126/
   pip install -r requirements/requirements_scoring.txt
   ```

   Ignore the warning about `nvidia-nccl-cu12` and `numpy` version, it is not a problem.

   About FFMPEG, please refer to the [`INSTALL.md`](scoring/motion/INSTALL.md) for detailed instructions on how to install ffmpeg. After installation, replace the `FFMPEG_PATH` variable in the [`scoring/motion/inference.py`](scoring/motion/inference.py) and [`utils/cut.py`](utils/cut.py) with the actual path to your ffmpeg executable, default is `/usr/local/bin/ffmpeg`.

   [Optional] if your videos are in av1 codec instead of h264, you need to install ffmpeg (already in our requirement script), then run the following to make conda support av1 codec:

   ```bash
   pip uninstall opencv-python
   conda install -c conda-forge opencv==4.11.0
   ```
3. Package needed for annotation

   ```bash
   pip install -r requirements/requirements_annotation.txt
   ```

   Compile the extensions for the camera tracking module:

   ```bash
   cd camera_pose_annotation/base
   python setup.py install
   ```

4. [Optional] Package needed for visualization

   ```bash
   pip install plotly
   pip install -e viser
   ```

### Model Weight

Download the model weights used in our experiments:

```bash
bash scripts/download_checkpoints.sh
```

Or you can manually download the model weights from the following links and place them in the appropriate directories.

| Model               | File Name               | URL                                                                                                             |
| ------------------- | ----------------------- | --------------------------------------------------------------------------------------------------------------- |
| Aesthetic Predictor | aesthetic               | [🔗](https://github.com/christophschuhmann/improved-aesthetic-predictor/raw/main/sac+logos+ava1-l14-linearMSE.pth) |
| MegaSAM             | megasam_final           | [🔗](https://github.com/mega-sam/mega-sam/blob/main/checkpoints/megasam_final.pth)                                 |
| RAFT                | raft-things             | [🔗](https://drive.google.com/uc?id=1MqDajR89k-xLV0HIrmJ0k-n8ZpG6_suM)                                             |
| Depth Anything      | Depth-Anything-V2-Large | [🔗](https://huggingface.co/depth-anything/Depth-Anything-V2-Large)                                                |
| UniDepth            | unidepth-v2-vitl14      | [🔗](https://huggingface.com/lpiccinelli/unidepth-v2-vitl14)                                                        |
| SAM                 | sam2.1-hiera-large      | [🔗](https://huggingface.co/facebook/sam2.1-hiera-large)                                                           |


## Quick Start

The whole pipeline is illustrated in the figure below:

<p align="center">
  <img src="assets/pipeline.png"  height=340>
</p>

1. Scoring

   ```bash
   bash scripts/scoring.sh
   ```

   Inside the [`scoring.sh`](scripts/scoring.sh) script, you need to set the following variables:

   - `ROOT_VIDEO` is the directory containing the input video files.
   - `OUTPUT_DIR` is the directory where the output files will be saved.
2. Annotation

   ```bash
   bash scripts/annotation.sh
   ```

   Inside the [`annotation.sh`](scripts/annotation.sh) script, you need to set the following variables:

   - `CSV` is the CSV file generated by the scoring script, default is `$OUTPUT_DIR/results.csv`.
   - `OUTPUT_DIR` is the directory where the output files will be saved.
3. Caption

   ```bash
   bash scripts/caption.sh
   ```

   Inside the [`caption.sh`](scripts/caption.sh) script, you need to set the following variables:

   - `CSV` is the CSV file generated by the annotation script, default is `$OUTPUT_DIR/results.csv`.
   - `SRC_DIR` is the annotation output directory, default is the same as the `OUTPUT_DIR` in the annotation step.
   - `OUTPUT_DIR` is the directory where the output files will be saved.
   - The API keys for the LLM models used in the captioning step. You can replace them with your own API keys.
4. Visualization

   - You can visualize the `poses.npy` in the `reconstruction` folder of each annotated clip using the [`visualize_pose.py`](viser/visualize_pose.py) script.
   - You can visualize the final annotation result(`sgd_cvd_hr.npz`) using the [`visualize_megasam.py`](viser/visualize_megasam.py) script.
   
   Note that if you want to visualize any clip in our dataset, you need to use the script [`pack_clip_assets.py`](utils/pack_clip_assets.py) to unify the depth, RGB frames, intrinsics, extrinsics, etc. of that clip into a single npz file first. And then you can use the visualization script to visualize it.


## Docker Setup and Usage

We provide a Dockerfile to create a fully configured environment that includes all dependencies, including a custom-built FFmpeg with NVIDIA acceleration. This is the recommended way to ensure reproducibility and avoid environment-related issues.

### Prerequisites: Setting up the Host Environment

Before building and running the Docker container, your host machine must be configured to support GPU access for Docker.

1.  **NVIDIA Drivers**: Ensure you have the latest NVIDIA drivers installed. You can verify this by running `nvidia-smi`.

2.  **Docker Engine**: Install Docker on your system. Follow the official instructions at [docs.docker.com/engine/install/](https://docs.docker.com/engine/install/).

3.  **NVIDIA Container Toolkit**: This toolkit allows Docker containers to access the host's NVIDIA GPU. Install it using the following commands (for Debian/Ubuntu):

    ```bash
    # Add the GPG key
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    
    # Add the repository
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
      sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    # Update package lists and install the toolkit
    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit
    
    # Configure Docker to use the NVIDIA runtime
    sudo nvidia-ctk runtime configure --runtime=docker
    
    # Restart the Docker daemon to apply the changes
    sudo systemctl restart docker
    ```
    For other operating systems, please refer to the [official NVIDIA documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).

### Build and Run the Container

Once the prerequisites are met, you can build and run the container using one of the following options.

#### Option 1: Using the Helper Script

We provide a convenient script to build the Docker image.

1.  **Build the image**:
    ```bash
    # The --num-jobs argument specifies the number of parallel jobs for compilation. 
    # Adjust it based on your machine's CPU cores.
    bash scripts/build_gpu_docker.sh --num-jobs 8
    ```

2.  **Run the container**:
    ```bash
    # This command starts an interactive session inside the container,
    # with the project directory mounted at /workspace.
    docker run --gpus all --rm -it -v $(pwd):/workspace -w /workspace spatialvid-gpu:latest bash
    ```

#### Option 2: Manual Build and Run

You can also build and run the image using standard Docker commands from the root of the repository.

1.  **Build the GPU image**:
    ```bash
    docker build -f Dockerfile \
      --build-arg NUM_JOBS=8 \
      -t spatialvid-gpu:latest .
    ```

2.  **Run the container**:
    ```bash
    docker run --gpus all --rm -it \
      -v $(pwd):/workspace \
      -w /workspace \
      spatialvid-gpu:latest bash
    ```

3.  **Verify the environment (inside the container)**:
    Once inside the container, you can verify that FFmpeg and PyTorch are correctly installed and can access the GPU.
    ```bash
    # Check the custom FFmpeg build
    /usr/local/bin/ffmpeg -version

    # Check PyTorch and CUDA availability
    python3 -c "import torch; print(f'PyTorch: {torch.__version__}, CUDA: {torch.version.cuda}, GPU Available: {torch.cuda.is_available()}')"
    ```

## Dataset Download

Apart from downloading the dataset using terminal commands, we provide scripts to download the SpatialVID/SpatialVID-HQ dataset from HuggingFace. Please refer to the [`download_SpatialVID.py`](utils/download_SpatialVID.py) script for more details.

We also provide our script to download the raw videos from YouTube. You can refer to the [`download_YouTube.py`](utils/download_YouTube.py) script for more details.

## References

Thanks to the developers and contributors of the following open-source repositories, whose invaluable work has greatly inspire our project:

- [Open-Sora](https://github.com/hpcaitech/Open-Sora): An initiative dedicated to efficiently producing high-quality video.
- [MegaSaM](https://github.com/mega-sam/mega-sam): An accurate, fast and robust casual structure and motion from casual dynamic videos.
- [Depth Anything V2](https://github.com/DepthAnything/Depth-Anything-V2): A model for monocular depth estimation.
- [UniDepthV2](https://github.com/lpiccinelli-eth/UniDepth): A model for universal monocular metric depth estimation.
- [SAM2](https://github.com/facebookresearch/sam2): A model towards solving promptable visual segmentation in images and videos.
- [Viser](https://viser.studio/latest/): A library for interactive 3D visualization in Python.

Our repository is licensed under the Apache 2.0 License. However, if you use MegaSaM or other components in your work, please follow their license.

## Citation

```bibtex
@misc{wang2025spatialvidlargescalevideodataset,
      title={SpatialVID: A Large-Scale Video Dataset with Spatial Annotations}, 
      author={Jiahao Wang and Yufeng Yuan and Rujie Zheng and Youtian Lin and Jian Gao and Lin-Zhuo Chen and Yajie Bao and Yi Zhang and Chang Zeng and Yanxi Zhou and Xiaoxiao Long and Hao Zhu and Zhaoxiang Zhang and Xun Cao and Yao Yao},
      year={2025},
      eprint={2509.09676},
      archivePrefix={arXiv},
      primaryClass={cs.CV},
      url={https://arxiv.org/abs/2509.09676}, 
}
```
