# Project Report: DevOps Resume Analyzer

## 1. Project Overview
The **DevOps Resume Analyzer** is a full-stack, AI-powered web application designed to evaluate user resumes. It extracts text, calculates an ATS (Applicant Tracking System) score, and provides actionable improvement suggestions.

Beyond the application itself, the core objective of this project was to implement a robust, automated DevOps lifecycle demonstrating Continuous Integration and Continuous Deployment (CI/CD), Infrastructure as Code (IaC), and automated testing.

## 2. System Architecture & Tech Stack

### Application Layer
- **Frontend**: Built with Next.js 16, React 19, and Tailwind CSS. Provides the user interface for uploading resumes and displaying the AI-generated report.
- **Backend**: Built with FastAPI (Python). Handles the API requests, uses `pdfplumber` to extract text from PDF files, and interfaces with the Groq API.
- **AI Integration**: Groq API is utilized as the LLM engine to perform lightning-fast analysis of the resume text.

### DevOps & Observability Layer
- **Infrastructure as Code (IaC)**: Terraform is used for both local container networking and full AWS Cloud provisioning (custom VPC, public subnet, route table, security groups, EC2 instance, and IAM SSM role).
- **Continuous Integration (CI)**: Jenkins automates the build pipeline, triggered by GitHub pushes.
- **Static Code Analysis**: SonarQube inspects the code for bugs, vulnerabilities, and code smells. A Quality Gate ensures poor code fails the build.
- **Containerization**: Docker and Docker Compose package the frontend, backend, Prometheus, Grafana, and Node Exporter into isolated environments.
- **Observability & Monitoring**: Prometheus scrapes application metrics via `prometheus-fastapi-instrumentator` (`/metrics`) and host metrics via `node-exporter`. Grafana visualizes real-time throughput, p50/p95 latency, and system resource utilization via provisioned dashboards.
- **Automated UI Testing**: Pytest and Selenium WebDriver run automated End-to-End (E2E) tests against the Next.js frontend using a Headless Chrome browser.

## 3. The CI/CD Pipeline Workflow

The automated Jenkins pipeline (`Jenkinsfile`) executes the following stages sequentially:

1. **Checkout Code**: Pulls the latest commit from the `master` branch.
2. **Code Quality (SonarQube)**: Scans the codebase. The pipeline pauses at the **Quality Gate**; if the code fails the security/quality thresholds, the pipeline aborts.
3. **Build & Start App (Docker)**: Uses `docker compose` to build fresh images for the frontend and backend, and starts them along with the Prometheus and Grafana stack in detached mode.
4. **Automated UI Testing (Selenium)**: Spins up a temporary, isolated Python container on the application network to execute Selenium tests against the running frontend to verify UI integrity.
5. **Deploy to AWS / Production**: Deploys verified containers to the target environment using production compose configurations.
6. **Clean Up**: On failure, tears down broken application and monitoring containers to leave a clean environment for the next build.

## 4. Observability & Monitoring Architecture

The observability stack provides complete visibility across application and infrastructure health:

- **FastAPI Instrumentation**: Automatically exposes Prometheus metrics at `/metrics` including request count, response time histograms, and HTTP status codes.
- **Host Metrics (Node Exporter)**: Mounts host `/proc` and `/sys` to gather CPU, memory, filesystem, and network interface metrics.
- **Prometheus TSDB**: Scrapes FastAPI every 5 seconds and retains time-series data for 15 days.
- **Grafana Dashboards as Code**: Pre-configured datasources and custom JSON dashboard (`fastapi-overview.json`) automatically provisioned at startup, providing immediate insights into traffic spikes, latency anomalies, and system load.

## 5. Production Cloud Deployment (AWS & Terraform)

The production setup in `terraform/aws/` enables repeatable, one-command cloud provisioning:

- **Networking**: Dedicated VPC (`10.0.0.0/16`) with an Internet Gateway, public subnet, and custom route tables.
- **Security Groups**: Tight ingress rules restricted to ports 80, 443, 3000 (UI), 8000 (API), 9090 (Prometheus), 3001 (Grafana), and 22 (SSH).
- **IAM SSM Profile**: Attaches `AmazonSSMManagedInstanceCore` to the EC2 instance, enabling secure, encrypted browser-based terminal access via AWS Systems Manager without opening SSH ports to the world.
- **Automated Cloud-Init (`user_data.sh`)**: On first boot, automatically configures Docker, downloads Docker Compose, clones the application repository, configures `.env` with the allocated Elastic IP, builds and launches the production Docker Compose stack, and establishes a systemd unit for automatic reboot recovery.

## 6. Challenges Encountered & Resolutions

During the pipeline development, several complex DevOps challenges were encountered and successfully resolved:

### Issue 1: Docker Daemon Permission Denied
* **Error**: `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock`
* **Root Cause**: The Jenkins container, running as the default `jenkins` user (UID 1000), lacked administrative permissions to access the host's Docker socket.
* **Resolution**: Modified the Terraform configuration (`main.tf`) to force the Jenkins container to run as the `root` user, granting it full access to orchestrate Docker containers.

### Issue 2: Git "Unsafe Repository" Error
* **Error**: `fatal: not in a git directory` during the Checkout stage.
* **Root Cause**: After switching the Jenkins container to run as `root`, Git detected a user ownership mismatch (the existing workspace files were owned by UID 1000). Git blocked operations for security reasons.
* **Resolution**: Executed `git config --global --add safe.directory '*'` inside the Jenkins container to establish trust, and wiped the stale workspace to force a clean clone.

### Issue 3: Missing Docker CLI in Jenkins
* **Error**: `docker: not found` during the Build stage.
* **Root Cause**: The fresh `jenkins/jenkins:lts` image deployed via Terraform does not include the Docker CLI natively.
* **Resolution**: Ran the official Docker installation script (`curl -fsSL https://get.docker.com | sh`) inside the Jenkins container to install the required CLI and Docker Compose plugins.

### Issue 4: Container Name Conflicts
* **Error**: `Conflict. The container name "/resume-backend" is already in use...`
* **Root Cause**: Stale containers from previous failed pipeline runs were left orphaned because the cleanup stage (`docker compose down`) did not execute successfully.
* **Resolution**: Manually pruned the orphaned containers. To prevent future issues in a Continuous Deployment scenario, the pipeline strategy was adapted to run `docker compose down || true` *before* the build phase, ensuring a clean slate for every deployment.

### Issue 5: Container Network Host Resolution in E2E Testing
* **Error**: Selenium tests failing to connect to `localhost:3000` inside the test container.
* **Root Cause**: When tests execute inside a separate Docker container (`e2e-test-runner`), `localhost` resolves to the test container itself rather than the frontend service container.
* **Resolution**: Updated `test_homepage.py` to dynamically detect whether it is executing inside a Docker bridge network (resolving `frontend:3000`) or locally on the host (`localhost:3000`), and configured Jenkinsfile to supply the Docker bridge URL explicitly.

## 7. Conclusion
The project successfully demonstrates a modern, end-to-end DevOps workflow. It bridges the gap between software engineering and IT operations by automating the entire lifecycle—from code push to quality inspection, containerized building, automated UI testing, full-stack observability, and automated AWS cloud deployment.
