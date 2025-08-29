# Self-Service On-Prem Datalab Inference Container

This repo contains scripts to pull and run [Datalab's self-service on-prem container](https://documentation.datalab.to/docs/on-prem/self-serve/overview).

If you need help troubleshooting or have questions, please reach out to [support@datalab.to](mailto:support@datalab.to).

- To run the container, you will need your license key.
- To pull images or search for tags in our registry, you will need your GCloud service account key.
- Both of these are available to you in your account at [https://www.datalab.to/app/subscription](https://www.datalab.to/app/subscription) after you check out.

# Prerequisites

- A VM running one of our recommended GPUs (see below)
- Docker running on that VM
- The `gcloud` CLI on the path (see [install instructions](https://cloud.google.com/sdk/docs/install))

# Running the container

You can run the container by logging into your VM and running the below:

```bash
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

This will show a table of available tags and their digests. You can also use:
- `FORMAT=tags-only ./list-images.sh` - Show only the tag names
- `FORMAT=json ./list-images.sh` - Show full JSON output

Use the tag names with the `CONTAINER_VERSION` environment variable to run a specific version instead of the latest (which it runs by default).

## Configuration

Other environment variables you can set include:

- `CONTAINER_VERSION` if you don't want to use the image tagged `:latest`.
- `INFERENCE_PORT` to set the port to a value other than 8000.
- `INFERENCE_HOST` to control which network interface the container binds to (default: `127.0.0.1` for local access only, set to `0.0.0.0` for external access).
- `DOCKER_EXTRA_ARGS` to submit additional args to Docker.

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

If you need concurrency across > 1 GPU, contact us regarding a custom contract at [support@datalab.to](mailto:support@datalab.to). In addition to a new license, different images and deployment instructions are also required for such a set up.

# Recommended GPUs

We recommend running the container on one of these GPUs, in roughly this order:

- H100
- L40S
- A10
- T4

# Tuning

The container is tuned to work well on any of the above GPUs, but we're happy to provide recommendations for your particular workloads/constraints.

Send us a note at [support@datalab.to](mailto:support@datalab.to).
