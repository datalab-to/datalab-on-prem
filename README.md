# On-Prem Datalab Inference Container

This repo contains scripts to pull and run Datalab's on-prem container, requiring a license.

If you need help troubleshooting or have questions, please reach out to [support@datalab.to](mailto:support@datalab.to).

- To run the container, you will need your license key.
- To pull images or search for tags in our registry, you will need your GCloud service account key.

# Prerequisites

- A VM running one of our recommended GPUs (see below)
- Docker running on that VM
- The `gcloud` CLI on the path (see [install instructions](https://cloud.google.com/sdk/docs/install))


# Container Types

Datlab offers a container for each of our models:

- **`marker`** (default): Our original Marker/Surya-based inference engine. Fastest, but less accurate.
- **`chandra-small`**: A smaller version of Chandra. A balance of accuracy and latency -- in between `marker` and `chandra`.
- **`chandra`**: Our [latest model, which tops third-party OCR benchmarks](https://www.datalab.to/blog/introducing-chandra). Slowest, but most accurate.

By default, scripts use the `marker` container. To use a different model type, set the `DATALAB_MODEL` environment variable (see examples below).

# Running the container

You can run the container by logging into your VM and running the below:

```bash
export DATALAB_LICENSE_KEY=your-license-key
export SERVICE_ACCOUNT_KEY_FILE=path/to/key.json
./run-datalab-inference-container.sh
```

This will run the default `marker` container. To run a different model type:

```bash
# Run Chandra container
export DATALAB_MODEL=chandra
export DATALAB_LICENSE_KEY=your-license-key
export SERVICE_ACCOUNT_KEY_FILE=path/to/key.json
./run-datalab-inference-container.sh

# Run Chandra-small container
export DATALAB_MODEL=chandra-small
export DATALAB_LICENSE_KEY=your-license-key
export SERVICE_ACCOUNT_KEY_FILE=path/to/key.json
./run-datalab-inference-container.sh
```

The container's server runs on port 8000 by default and maps 8000 on the host by default.

## Running in Background (Daemon Mode)

To run the container in the background so you can log out of your VM:

```bash
export DATALAB_LICENSE_KEY=your-license-key
export SERVICE_ACCOUNT_KEY_FILE=path/to/key.json
./run-datalab-inference-container.sh --daemon
```

Useful commands:
- `./run-datalab-inference-container.sh --status` - Check if container is running
- `./run-datalab-inference-container.sh --stop` - Stop the container
- `docker ps` - See all running containers (look for `datalab-inference`)

Running in daemon mode automatically restarts the container if it crashes.

## Health Check

The container provides a health check endpoint at `/health_check` that returns `{"status": "healthy"}` when the server accepting requests is running properly.

```bash
curl http://localhost:8000/health_check
```

## Listing Available Container Versions

To see what container versions are available in the registry:

```bash
export SERVICE_ACCOUNT_KEY_FILE=path/to/key.json
./list-images.sh
```

This will show a table of available tags and their digests for the default `marker` container. To list versions for other model types:

```bash
# List Chandra container versions
DATALAB_MODEL=chandra SERVICE_ACCOUNT_KEY_FILE=path/to/key.json ./list-images.sh

# List Chandra-small container versions
DATALAB_MODEL=chandra-small SERVICE_ACCOUNT_KEY_FILE=path/to/key.json ./list-images.sh
```

You can also use:
- `FORMAT=tags-only ./list-images.sh` - Show only the tag names
- `FORMAT=json ./list-images.sh` - Show full JSON output

Use the tag names with the `CONTAINER_VERSION` environment variable to run a specific version instead of the latest (which it runs by default).

## Configuration

Other environment variables you can set include:

- `DATALAB_MODEL` to select the model type: `marker` (default), `chandra`, or `chandra-small`.
- `CONTAINER_VERSION` if you don't want to use the image tagged `:latest`.
- `INFERENCE_PORT` to set the port to a value other than 8000.
- `INFERENCE_HOST` to control which network interface the container binds to (default: `127.0.0.1` for local access only, set to `0.0.0.0` for external access).
- `DOCKER_EXTRA_ARGS` to submit additional args to Docker.

### GPU Configuration (Chandra and Chandra-Small only)                                                                                                                                              
                                                                                                                                                                                                      
The container automatically detects available GPUs, VRAM, and model type to set optimal defaults. By default, it scales to all GPUs visible to the container using data parallelism, and scales the necessary client side concurrency automatically. **You should only override these if you know what you're doing.**                                                                                                                                                              

> **Note:** The container can only use GPUs that are exposed to it. Use `--gpus all` (or `--gpus device=0,1,2` for specific GPUs) when running the container.

- `TENSOR_PARALLEL_SIZE` — number of GPUs to split a single model across (default: `1`).
- `DATA_PARALLEL_SIZE` — number of model replicas to run in parallel (default: `NUM_GPUS / TENSOR_PARALLEL_SIZE`).
- `MAX_NUM_SEQS` — maximum concurrent sequences per replica. Auto-tuned based on VRAM and model type. Will auto-scale if using `TENSOR_PARALLEL_SIZE`>1
- `MAX_NUM_BATCHED_TOKENS` — maximum tokens per batch pre replica. Auto-tuned based on VRAM. Will auto-scale if using `TENSOR_PARALLEL_SIZE`>1
- `MAX_CONCURRENT_VLLM` — total client-side concurrency limit (default: `MAX_NUM_SEQS * DATA_PARALLEL_SIZE`).
- `GPU_MEMORY_UTILIZATION` - % of GPU memory utilized by the model runner.
  
## Exposing the container externally

By default, the container is only accessible from the local machine. To make it accessible from external networks:

```bash
export DATALAB_LICENSE_KEY=your-license-key
export SERVICE_ACCOUNT_KEY_FILE=path/to/key.json
export INFERENCE_HOST=0.0.0.0
./run-datalab-inference-container.sh
```

When exposing the container externally, ensure your VM's firewall allows inbound traffic on the inference port, and **carefully consider the security implications of making the service publicly accessible in your scenario.**

## Using a reverse proxy

You may put a reverse proxy in front of the container provided it is not used to load balance requests.

This might be desirable if, e.g. you want to send requests to the machine running the container over SSL. Both nginx and Caddy are good options for this.

## Running multiple instances

Our self-service on-prem license allows 1-to-3 running instances, each of which must stand alone. Instances beyond the first must be purchased ([details are here](https://documentation.datalab.to/docs/on-prem/self-serve/overview)).

Our intent with multiple instances is to allow customers to run instances in different environments/contexts (e.g. dev, stage, production).

If you need more instances, contact us regarding a custom contract at [support@datalab.to](mailto:support@datalab.to). In addition to a new license, different images and deployment instructions are also required for such a set up.

# Recommended GPUs

## Marker

We recommend running Marker on one of these GPUs, in roughly this order:

- H100
- L40S
- A10
- T4

## Chandra Small

For Chandra Small, we recommend two classes of GPUs, one at the 24GB VRAM tier and the other at the 80GB VRAM tier:

- **24GB VRAM**: A10, L4
- **80GB VRAM**: H100, A100

You will get better performance out of GPUs at the 80GB VRAM tier.

## Chandra

For Chandra, we recommend running either of - B200, H200, H100, A100.
