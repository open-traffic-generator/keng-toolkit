# keng-toolkit

`keng-toolkit` contains `ixops.sh`, a helper for creating an OTG/Ixia test environment, provisioning the required Kubernetes or Docker topology, and running the example Go tests.

## Prerequisites

- Linux host with Docker and sudo access
- Git, curl, and a working internet connection
- A GitHub account with a personal access token
- Go 1.26+ (or let `ixops.sh` install the required tooling)

The script expects a local `auth.yaml` file. Start from the template:

```bash
cp auth-template.yaml auth.yaml
```

Edit `auth.yaml` and set the values under `opts`:

```yaml
opts:
  github-user: "your-github-username"
  github-pat: "your-github-personal-access-token"
```

`config.yaml` controls the image tags and release versions used by the toolkit. Review it before creating a topology.

## Quick start

From the repository root:

```bash
./ixops.sh setup
```

This installs the toolchain needed by the environment (`go`, `yq`, `kind`, `kubectl`, and related dependencies) and creates the default Kind-based test setup.

To tear down the environment when you are finished:

```bash
./ixops.sh cleanup
```

## Typical ixops commands

The script exposes workflow helpers that match the repo contents. Valid examples from this checkout are:

```bash
./ixops.sh setup
./ixops.sh cleanup
./ixops.sh new_kne_topo deployments/kne/cp_dp_b2b/topology.yaml vm-license
./ixops.sh rm_kne_topo deployments/kne/cp_dp_b2b/topology.yaml
./ixops.sh new_docker_compose_topo deployments/docker_compose/ixhw_server/topology.yaml vm-license
./ixops.sh new_docker_ixhw_topo vm-license
./ixops.sh rm_docker_ixhw_topo vm-license
```

Common patterns:

- `setup`: install prerequisites and initialize the cluster
- `new_kne_topo <path> <license-server>`: create a KNE topology from a YAML or `.txt` file
- `rm_kne_topo <path>`: delete the topology and namespace
- `new_docker_compose_topo <path> <license-server>`: create a Docker Compose topology
- `new_docker_ixhw_topo <license-server>`: start the IXHW controller stack in Docker

The `deployments/` tree in this repo currently includes KNE and Docker Compose topologies; there is no containerlab topology bundle checked in here.

The license-server value is typically one of the names defined under `license-servers` in `config.yaml`, such as `vm-license`, `container-kne`, or `legacy`.

## Running the Python example

The repository includes a Python snappi example at `examples/cp_dp_b2b/quickstart_cp_dp.py`.

Before running it, install the Python dependencies:

```bash
cd examples
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
```

Make sure the OTG controller is running and the ports exist in your environment.

### Run the live example

```bash
cd examples/cp_dp_b2b
python3 quickstart_cp_dp.py --port-a "xgssdl-711954.ccu.is.keysight.com;1;1" --port-z "xgssdl-711954.ccu.is.keysight.com;1;5"
```

If your lab uses different port names, replace `eth1` and `eth2` with the actual interfaces exposed by your environment.

### Optional: compile-check the Python script

This validates the script parses successfully without running against a live OTG controller:

```bash
cd examples/cp_dp_b2b
python3 -m py_compile quickstart_cp_dp.py
```

## Notes

- `ixops.sh` reads `auth.yaml` before running any workflow that needs GitHub credentials.
- `config.yaml` controls the release pins for container images and required tools.
- For a full environment, start by creating the topology and then run the snappi/Go test against the OTG service exposed by the controller.
