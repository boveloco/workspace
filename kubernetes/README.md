# Kubernetes Cluster

This repository contains the configuration files for the Kubernetes cluster. The cluster is built using the `k3s` and detailed installation instructions can be found in `ansible/playbook.yaml`.

Decisions regarding the cluster setup are documented in `Decisions.md`. You can follow the roadmap through the [GitHub Project](https://github.com/users/boveloco/projects/2) associated with this repository.

## Cluster Specifications

The following table outlines the key specifications of the cluster. For more details about the cluster architecture, refer to the SVG file located at `../architecture.svc`.

| Specification       | Details          |
| ------------------- | ---------------- |
| **Cluster Version** | v1.32.2          |
| **CNI**             | Cilium           |
| **CSI**             | LocalPathStorage |
| **Master Nodes**    | 1                |
| **Worker Nodes**    | 3                |
| **Database**        | SQLite           |
| **High Availability** | No             |
