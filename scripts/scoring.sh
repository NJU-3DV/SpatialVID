#!/bin/bash
ROOT_VIDEO=test
OUTPUT_DIR=output
mkdir -p ${OUTPUT_DIR}

GPU_NUM=8
CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
NUM_WORKERS=$((GPU_NUM * 2))

ROOT_CLIPS=${OUTPUT_DIR}/clip
ROOT_META=${OUTPUT_DIR}/meta
ROOT_FIG=${OUTPUT_DIR}/fig
ROOT_TEMP=${OUTPUT_DIR}/temp

for dir in ${ROOT_VIDEO} ${ROOT_CLIPS} ${ROOT_META} ${ROOT_FIG} ${ROOT_TEMP}; do
    if [ ! -d ${dir} ]; then
        mkdir -p ${dir}
    fi
done

measure_time() {
    local step_number=$1
    shift
    local green="\e[32m"
    local red="\e[31m"
    local no_color="\e[0m"
    local yellow="\e[33m"
    
    start_time=$(date +%s)
    echo -e "${green}Step ${step_number} started at: $(date)${no_color}"

    "$@"

    end_time=$(date +%s)
    echo -e "${red}Step ${step_number} finished at: $(date)${no_color}"
    echo -e "${yellow}Duration: $((end_time - start_time)) seconds${no_color}"
    echo "---------------------------------------"
}

# # 1.1 Create a meta file from a video folder. This should output ${ROOT_META}/meta.csv
# CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES} measure_time 1.1 python utils/convert.py \
#   --video_dir ${ROOT_VIDEO} \
#   --output ${ROOT_META}/meta.csv

# # 1.2 Get video information and remove broken videos. This should output ${ROOT_META}/meta_info_fmin${fmin_1}.csv
# CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES} measure_time 1.2 python utils/get_info.py \
#   --csv_path ${ROOT_META}/meta.csv \
#   --csv_save_path ${ROOT_META}/meta_info.csv \
#   --num_workers 16

# # 2.1 Detect scenes. This should output ${ROOT_META}/meta_info_fmin${fmin_1}_timestamp.csv
# # Also, you can set the params like "--start-remove-sec 0.5 --end-remove-sec 0.5"
# CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES} measure_time 2.1 python utils/scene_detect.py \
#   --csv_path ${ROOT_META}/meta_info.csv \
#   --num_workers 64 \
#   --frame_skip 2\
#   --start_remove_sec 0.3 \
#   --end_remove_sec 0.3 \
#   --min_seconds 3 \
#   --max_seconds 15

# # 2.2 Get clips. This should output ${ROOT_META}/clips_info.csv
# CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES} measure_time 2.2 python utils/get_clip.py \
#   --csv_path ${ROOT_META}/meta_info_timestamp.csv \
#   --csv_save_dir ${ROOT_META} \
#   --num_workers $((GPU_NUM * 4))

# # 2.3 Extract frames for scoring.
# CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES} measure_time 2.3 python utils/extract_frames.py \
#   --csv_path ${ROOT_META}/clips_info.csv \
#   --output_dir ${ROOT_FIG} \
#   --num_workers 64 \
#   --target_size "640*360"

# # 3.1 Predict aesthetic scores. This should output ${ROOT_META}/clips_info_aes.csv
# CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES} measure_time 3.1 torchrun --nproc_per_node ${GPU_NUM} scoring/aesthetic/inference.py \
#   --csv_path ${ROOT_META}/clips_info.csv \
#   --bs 16 \
#   --num_workers ${NUM_WORKERS} \
#   --fig_load_dir ${ROOT_FIG}

# # 3.2 Predict luminance scores. This should output ${ROOT_META}/clips_info_lum.csv
# CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES} measure_time 3.2 torchrun --nproc_per_node ${GPU_NUM} scoring/luminance/inference.py \
#   --csv_path ${ROOT_META}/clips_info.csv \
#   --bs 16 \
#   --num_workers ${NUM_WORKERS} \
#   --fig_load_dir ${ROOT_FIG}

# 3.3 get motion score. This should output ${ROOT_META}/clips_info_motion.csv
CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES} measure_time 3.3 python scoring/motion/inference.py \
  --csv_path ${ROOT_META}/clips_info.csv \
  --temp_save_dir ${ROOT_TEMP} \
  --num_workers $((GPU_NUM * 4)) \
  --gpu_num ${GPU_NUM}
  
# # 3.4 get text by OCR using PaddleOCR, this should output ${ROOT_META}/clips_info_ocr.csv
# CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES} measure_time 3.4 python scoring/ocr/inference.py \
#   --csv_path ${ROOT_META}/clips_info.csv \
#   --fig_load_dir ${ROOT_FIG} \
#   --num_workers $((GPU_NUM * 4)) \
#   --gpu_num ${GPU_NUM}

# # 4 merge all the scores. This should output ${ROOT_META}/clips_with_score.csv
# CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES} measure_time 4 python utils/merge_tables.py \
#   --csv_dir ${ROOT_META} \
#   --output ${ROOT_META}/clips_scores.csv

# # 5 Filter the clips.
# CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES} measure_time 5 python utils/filter.py \
#   --csv_path ${ROOT_META}/clips_scores.csv \
#   --csv_save_path ${ROOT_META}/filtered_clips.csv \
#   --aes_min 4 \
#   --lum_min 20 \
#   --lum_max 140 \
#   --motion_min 2 \
#   --motion_max 14 \
#   --ocr_max 0.3

# # 6 Cut the clips.
# CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES} measure_time 6 python utils/cut.py \
#   --csv_path ${ROOT_META}/filtered_clips.csv \
#   --csv_save_path ${OUTPUT_DIR}/results.csv \
#   --video_save_dir ${ROOT_CLIPS} \
#   --num_workers $((GPU_NUM * 4)) \
#   --gpu_num $GPU_NUM
