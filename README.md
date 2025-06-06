# Prerequisites
- Sealed secrets and credentials are managed in the infrastructure repository
- Ensure the following secrets exist in the `argowf` namespace:
  - `minio-credentials-wf`
  - `github-credentials` (optional, for image pushing)
