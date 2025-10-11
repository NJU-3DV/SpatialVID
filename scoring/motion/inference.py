"""
Motion analysis script for video quality assessment using FFmpeg and VMAF.
Calculates motion scores for video clips using hardware acceleration when available.
"""

import os
import argparse
import pandas as pd
import subprocess
from multiprocessing import Manager
import queue
import concurrent.futures
from tqdm import tqdm

FFMPEG_PATH = "/usr/bin/ffmpeg"


def get_ffmpeg_acceleration():
    """
    Auto detect the best acceleration method.
    Priority: NVIDIA GPU > CPU.
    """
    try:
        # Get the list of ffmpeg configuration
        output = subprocess.check_output(
            [FFMPEG_PATH, "-version"], stderr=subprocess.DEVNULL
        ).decode("utf-8")

        if "--enable-cuda-nvcc" and "--enable-libvmaf" in output:  # NVIDIA GPU
            return "nvidia"
        else:
            return "cpu"  # Use CPU
    except Exception as e:
        print(f"FFmpeg acceleration detection failed: {e}")
        return "cpu"


ACCELERATION_TYPE = get_ffmpeg_acceleration()
print(f"FFmpeg acceleration type: {ACCELERATION_TYPE}")


def process_single_row(video_path, args, process_id):
    """Process a single video to generate motion analysis CSV using FFmpeg."""
    path = os.path.join(
        args.temp_save_dir, os.path.basename(video_path).split(".")[0] + ".csv"
    )

    # Build FFmpeg command with appropriate acceleration
    command = [FFMPEG_PATH]
    if ACCELERATION_TYPE == "nvidia":
        command += [
            "-hwaccel",
            "cuda",
            "-hwaccel_output_format",
            "cuda",
            "-hwaccel_device",
            f"{process_id % args.gpu_num}",
        ]
    command += ["-i", f"{video_path}"]
   
    command += ["-i", f"{video_path}"]
    if ACCELERATION_TYPE == "nvidia":
        command += [
            "-filter_complex",
            f"[0:v]scale_cuda=format=yuv420p[dis],[1:v]scale_cuda=format=yuv420p[ref],[dis][ref]libvmaf_cuda=log_fmt=csv:log_path={path}",
        ]
    else:
        command += ["-lavfi", f"libvmaf=log_fmt=csv:log_path={path}"]
    command += ["-f", "null", "-"]
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error: {e.stderr}")


def calculate_score(row, args):
    """Calculate motion score for a specific video clip segment."""
    csv_path = os.path.join(args.temp_save_dir, f'{row["id_ori"]}.csv')
    df = pd.read_csv(csv_path)
    df = df[(df["Frame"] >= row["frame_start"]) & (df["Frame"] <= row["frame_end"])]
    mean_value = df["integer_motion2"].mean()
    return mean_value


def worker1(task_queue, args, process_id):
    """Worker function for processing videos in parallel."""
    while True:
        try:
            video_path = task_queue.get(timeout=1)
        except queue.Empty:
            break
        process_single_row(video_path, args, process_id)
        task_queue.task_done()


def worker2(task_queue, results_queue, args):
    """Worker function for calculating motion scores in parallel."""
    while True:
        try:
            index, row = task_queue.get(timeout=1)
        except queue.Empty:
            break
        value = calculate_score(row, args)
        results_queue.put((index, value))
        task_queue.task_done()


def parse_args():
    """Parse command line arguments for motion analysis."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv_path", type=str, required=True, help="Path to the CSV file")
    parser.add_argument(
        "--temp_save_dir",
        type=str,
        required=True,
        help="Directory to save the temporary files",
    )
    parser.add_argument(
        "--num_workers", type=int, default=None, help="#workers for concurrent.futures"
    )
    parser.add_argument(
        "--disable_parallel", action="store_true", help="disable parallel processing"
    )
    parser.add_argument("--gpu_num", type=int, default=1, help="gpu number")
    parser.add_argument("--skip_if_existing", action="store_true")
    args = parser.parse_args()
    return args


def main():
    args = parse_args()

    wo_ext, ext = os.path.splitext(args.csv_path)
    out_path = f"{wo_ext}_motion{ext}"
    if args.skip_if_existing and os.path.exists(out_path):
        print(f"Output CSV file '{out_path}' already exists. Exit.")
        exit()

    df = pd.read_csv(args.csv_path)
    video_paths = df["video_path"].unique()

    if args.disable_parallel:
        # Sequential processing
        results = []
        for video_path in tqdm(video_paths, desc="Processing videos"):
            result = process_single_row(video_path, args, 0)
            results.append(result)

        for index, row in tqdm(
            df.iterrows(), total=len(df), desc="Calculating scores"
        ):
            result = calculate_score(row, args)
            df.at[index, "motion"] = result
    else:
        # Parallel processing
        if args.num_workers is not None:
            num_workers = args.num_workers
        else:
            num_workers = os.cpu_count()

        # First phase: process videos to generate CSV files
        manager = Manager()
        task_queue = manager.Queue()

        for video_path in video_paths:
            task_queue.put(video_path)

        with concurrent.futures.ProcessPoolExecutor(
            max_workers=num_workers
        ) as executor:
            futures = []
            for id in range(num_workers):
                futures.append(executor.submit(worker1, task_queue, args, id))

            for future in tqdm(
                concurrent.futures.as_completed(futures),
                total=len(futures),
                desc="Finished workers",
            ):
                future.result()

        # Second phase: calculate motion scores
        result_queue = manager.Queue()
        task_queue = manager.Queue()

        for index, row in df.iterrows():
            task_queue.put((index, row))

        with concurrent.futures.ProcessPoolExecutor(
            max_workers=num_workers
        ) as executor:
            futures = []
            for _ in range(num_workers):
                futures.append(executor.submit(worker2, task_queue, result_queue, args))

            for future in tqdm(
                concurrent.futures.as_completed(futures),
                total=len(futures),
                desc="Finished workers",
            ):
                future.result()

        # Collect and sort results
        results = []
        while not result_queue.empty():
            results.append(result_queue.get())
        results.sort(key=lambda x: x[0])
        results = list(map(lambda x: x[1], results))
        df["motion score"] = results

    df.to_csv(out_path, index=False)
    print(f"New df with motion scores saved to '{out_path}'.")


if __name__ == "__main__":
    main()
