# 📋 Interview Questions & Answers — DevOps Resume Analyzer

This document contains the most commonly asked interview questions about this project, along with clear, concise answers you can use to explain your work confidently.

---

## 🔷 Project Overview

### Q1. What is this project and what problem does it solve?

**Answer:**
This is a DevOps Resume Analyzer — an AI-powered web application that helps job seekers improve their resumes. A user uploads their PDF resume, the backend parses it using ``pdfplumber``, and sends the text to the Groq AI API, which returns an ATS (Applicant Tracking System) score, identified skills, and actionable improvement suggestions.

The core goal of the project is to demonstrate a **complete, automated DevOps lifecycle** — from code commit to tested deployment — using real industry tools like Jenkins, Docker, SonarQube, Terraform, and Selenium.

---

### Q2. Walk me through the end-to-end flow of your DevOps pipeline.

**Answer:**
1. A developer pushes code to **GitHub**.
2. GitHub sends a webhook that **triggers the Jenkins pipeline**.
3. Jenkins pulls the latest code (**Checkout** stage).
4. **SonarQube** scans the codebase for bugs, vulnerabilities, and code smells.
5. The **Quality Gate** pauses the pipeline — if code quality is below threshold, the pipeline fails and nothing gets deployed.
6. If the code is good, Jenkins uses **Docker Compose** to build and start the Next.js frontend and FastAPI backend containers.
7. Jenkins spins up a temporary **Selenium** container that runs automated UI tests against the live frontend.
8. If all tests pass, the containers remain live (acting as **Continuous Deployment**). If they fail, the containers are cleaned up automatically.

---

## 🐳 Docker & Containerization

### Q3. Why did you use Docker Compose instead of running containers manually?

**Answer:**
Docker Compose lets you define, configure, and start multiple containers (frontend, backend, Jenkins, SonarQube) using a single ``docker-compose.yml`` file. Without it, you'd have to run separate ``docker run`` commands for each service, manage networking manually, and keep track of environment variables separately. Compose handles all of that declaratively, making it reproducible and easy to maintain.

---

### Q4. What is the difference between ``docker compose down`` and stopping individual services? Why does it matter here?

**Answer:**
- ``docker compose down`` stops **all** services defined in the Compose file, including Jenkins and SonarQube.
- Stopping individual services (``docker compose stop frontend backend``) leaves the CI/CD infrastructure (Jenkins, SonarQube) running.

In the Jenkins pipeline, using ``docker compose down`` would **kill Jenkins itself** mid-pipeline — which would crash the build. So the pipeline explicitly stops only the webapp containers, keeping Jenkins and SonarQube untouched.

---

### Q5. How does Docker-in-Docker (DinD) work in your Jenkins setup?

**Answer:**
Jenkins runs inside a Docker container. To let Jenkins build and run Docker containers for the application and tests, the Jenkins container needs access to the **host machine's Docker daemon**. This is done by mounting the Docker socket (``/var/run/docker.sock``) from the host into the Jenkins container via Terraform. This way, when Jenkins runs Docker commands, they actually execute on the host's Docker daemon — so all containers are siblings, not children, of the Jenkins container.

---

## ⚙️ Jenkins & CI/CD

### Q6. What triggers your Jenkins pipeline and how?

**Answer:**
The pipeline uses the ``githubPush()`` trigger in the ``Jenkinsfile``. When code is pushed to GitHub, GitHub sends a **webhook** HTTP request to the Jenkins server (on port 8080). Jenkins receives this event, matches it to the configured pipeline job, and starts a new build automatically.

---

### Q7. What happens if the pipeline fails midway? How do you handle cleanup?

**Answer:**
The ``post { failure { } }`` block in the Jenkinsfile handles this. If any stage fails:
- Jenkins runs ``docker compose stop frontend backend`` and ``docker compose rm -f frontend backend`` to tear down the broken application containers.
- Jenkins and SonarQube are left running since they are CI/CD infrastructure, not the app itself.
- The ``cleanWs()`` call in the ``always`` block ensures the Jenkins workspace is cleaned up regardless of success or failure.

---

### Q8. What is the difference between CI and CD? Where does each happen in your pipeline?

**Answer:**
- **CI (Continuous Integration)**: Automatically integrating code changes and verifying them through builds and tests. In this pipeline, the **Checkout → SonarQube → Quality Gate → Docker Build** stages represent CI.
- **CD (Continuous Deployment/Delivery)**: Automatically delivering the verified build to a running environment. In this pipeline, the **Selenium tests passing + containers staying live** represents Continuous Deployment. The **Deploy stage** is a placeholder for pushing to a real environment like AWS ECS.

---

## 🔍 SonarQube & Code Quality

### Q9. What is a Quality Gate in SonarQube and why is it important?

**Answer:**
A Quality Gate is a set of **pass/fail conditions** defined in SonarQube (e.g., no new critical bugs, code coverage above 80%, zero security vulnerabilities). After SonarQube finishes scanning, Jenkins calls ``waitForQualityGate abortPipeline: true``. If the code doesn't meet the defined thresholds, SonarQube reports a failure and Jenkins **aborts the entire pipeline before Docker even starts**. This prevents bad code from ever being built or deployed.

---

### Q10. What types of issues does SonarQube detect?

**Answer:**
SonarQube detects:
- **Bugs**: Code that is incorrect and likely to cause runtime failures.
- **Vulnerabilities**: Security weaknesses (e.g., SQL injection, exposed secrets).
- **Code Smells**: Maintainability issues that make code harder to understand and change.
- **Duplications**: Repeated blocks of code.
- **Coverage**: Percentage of code covered by unit tests.
- **Security Hotspots**: Code that requires manual review for potential security risks.

---

## 🏗️ Terraform & IaC

### Q11. Why did you use Terraform for local Docker containers instead of just using Docker Compose?

**Answer:**
To demonstrate the **core concepts of Infrastructure as Code (IaC)** without incurring cloud costs. Terraform separates *infrastructure provisioning* (creating networks, volumes, and long-running service containers) from *application orchestration* (Docker Compose). The Terraform configuration for Docker networks and volumes is structurally identical to what you would write for AWS VPCs, ECS clusters, or EBS volumes — it's a portfolio demonstration of IaC skills that scales directly to cloud environments.

---

### Q12. What is Terraform state and why is it important?

**Answer:**
Terraform state (stored in ``terraform.tfstate``) is a JSON file that tracks the **real-world resources Terraform has created**. It maps what's in your ``.tf`` config files to what actually exists in the infrastructure. Without state:
- Terraform wouldn't know if a resource already exists and would try to create it again.
- ``terraform destroy`` wouldn't know what to delete.

In a team environment, state is stored remotely (e.g., in AWS S3 with DynamoDB locking) to avoid conflicts between team members.

---

### Q13. What does ``terraform init``, ``terraform plan``, and ``terraform apply`` do?

**Answer:**
- ``terraform init``: Downloads the required provider plugins (e.g., the Docker provider) and sets up the backend. Run once per project.
- ``terraform plan``: Shows a **dry-run preview** of what Terraform will create, modify, or destroy — without making any changes.
- ``terraform apply``: **Executes the plan** and creates/modifies/destroys the real infrastructure. Prompts for confirmation unless ``-auto-approve`` is used.

---

## 🤖 Selenium & Testing

### Q14. Why did you run Selenium in headless mode?

**Answer:**
Jenkins runs inside a Docker container on a server — there is **no physical monitor or display server** available to open a browser window. Headless mode allows Chrome to render and interact with the web UI entirely in memory, without needing a screen. This makes it suitable for running in any server/CI environment.

---

### Q15. Why did you run Selenium tests inside a Docker container instead of directly on Jenkins?

**Answer:**
Running Chrome and Selenium directly inside the Jenkins container would require polluting the Jenkins environment with Google Chrome binaries, ChromeDriver dependencies, Xvfb, and Python packages. If Chrome updates or conflicts arise, it could destabilize the Jenkins master itself.

By spinning up a temporary, isolated Python container (`e2e-test-runner`) on demand:
- **Clean Environment**: Every test run gets a pristine environment with exact dependency versions.
- **Isolation**: Jenkins remains lightweight and dedicated purely to orchestrating the pipeline.
- **Disposability**: Once the tests finish, `docker run --rm` immediately destroys the container, leaving zero leftover artifacts or hanging browser processes.

---

### Q16. How does the Selenium container communicate with the running frontend?

**Answer:**
Both the frontend container (Next.js on port 3000) and the Selenium test container are on the **same Docker network** (``${COMPOSE_PROJECT_NAME}_default``). The ``docker run --network`` flag connects the test runner to that network. Inside the test container, the frontend is reachable via ``http://frontend:3000`` (using the Docker service name as a hostname) or via the host IP.

---

## 🧠 AI & Application

### Q17. Why did you choose Groq API over OpenAI?

**Answer:**
Groq uses specialized hardware called **LPUs (Language Processing Units)** instead of GPUs. LPUs are optimized specifically for the sequential, token-by-token nature of LLM inference. This makes Groq's token generation speed **dramatically faster** than GPU-based APIs like OpenAI. Since resume analysis requires processing large amounts of text and returning a detailed structured response, Groq provides a much faster and smoother user experience — often 5–10x faster than comparable OpenAI models.

---

### Q18. How does the resume parsing work at a high level?

**Answer:**
1. The user uploads a PDF via the Next.js frontend.
2. The file is sent as a multipart form request to the FastAPI backend.
3. The backend uses **``pdfplumber``** to extract raw text from the PDF, handling multi-page documents.
4. The extracted text is embedded into a structured **prompt** that instructs the Groq LLM to return an ATS score (0–100), a list of detected skills, missing keywords, and specific improvement suggestions.
5. The JSON response from Groq is parsed and returned to the frontend, which renders it in a clean, structured UI.

---

### Q19. What is an ATS score and why does it matter?

**Answer:**
ATS stands for **Applicant Tracking System** — software used by companies to automatically filter resumes before a human ever reads them. An ATS score represents how well a resume matches the keywords, formatting, and structure that ATS systems favor. A low ATS score means the resume may be **automatically rejected** before reaching a recruiter, even if the candidate is highly qualified. This application helps candidates optimize their resumes specifically for ATS compatibility.

---

### Q20. How would you scale this project to a real production environment?

**Answer:**
Several improvements would be needed:
- **Cloud Deployment**: Push Docker images to **AWS ECR** and deploy on **ECS Fargate** or **Kubernetes (EKS)** instead of a local machine.
- **Terraform for Cloud**: Replace the local Docker Terraform config with AWS resource blocks (VPC, ECS, RDS, ALB).
- **Secrets Management**: Use **AWS Secrets Manager** or **HashiCorp Vault** instead of ``.env`` files.
- **Monitoring**: Add **Prometheus + Grafana** or **AWS CloudWatch** for observability.
- **Remote Terraform State**: Store state in **S3 + DynamoDB** for team collaboration.
- **Branch-based Pipelines**: Use Jenkins **Multibranch Pipelines** to run separate pipelines for feature branches, staging, and production.

---

### Q21. What difficulty did you face in this project and how did you solve it?

**Answer:**
The most significant difficulty I faced was handling pipeline failures efficiently without breaking the live environment.

- **The Problem**: Initially, if a build failed at the during Selenium UI testing, my Jenkins pipeline would simply abort. This left broken or half-configured containers running on the server, which blocked ports and caused all subsequent builds to fail.
- **The Solution**: I solved this by implementing a `post { failure { ... } }` block in my `Jenkinsfile`. This ensures that anytime the pipeline fails, Jenkins explicitly runs cleanup commands (`docker compose stop` and `rm`) to tear down the bad containers. This creates a clean slate for the next push without requiring manual server intervention.

---

## 📈 Observability & Monitoring (Prometheus & Grafana)

### Q22. How is observability implemented in this project using Prometheus and Grafana?

**Answer:**
Observability is implemented as a multi-tier monitoring pipeline:
1. **Application Instrumentation**: The FastAPI backend integrates `prometheus-fastapi-instrumentator`, exposing a `/metrics` endpoint formatted in the OpenMetrics/Prometheus standard.
2. **Prometheus Scraping**: A Prometheus container polls the FastAPI `/metrics` endpoint every 5 seconds, along with a `node-exporter` container for host-level OS metrics.
3. **Grafana Dashboards**: Grafana is provisioned as code (via `monitoring/grafana/provisioning/`) with Prometheus as an automated data source and a pre-configured dashboard (`fastapi-overview.json`) tracking request throughput, latency percentiles, error rates, and CPU/memory utilization.

---

### Q23. What specific metrics are captured and why are they important?

**Answer:**
We capture both application and infrastructure metrics:
- **HTTP Request Rate & Status Codes (`http_requests_total`)**: Detects traffic spikes, 4xx client errors, or 5xx server failures in real time.
- **Request Latency (`http_request_duration_seconds_bucket`)**: Calculates p50 and p95 latency quantiles to ensure AI resume processing remains responsive.
- **Host Utilization (`node_cpu_seconds_total`, `node_memory_*`)**: Monitors EC2 CPU and RAM consumption from Node Exporter to prevent out-of-memory container crashes.

---

## ☁️ AWS Infrastructure as Code (Terraform AWS)

### Q24. How did you provision the production infrastructure on AWS using Terraform?

**Answer:**
The `terraform/aws/` directory automates the complete AWS infrastructure lifecycle:
- **Networking (`vpc.tf`)**: Creates a custom VPC (`10.0.0.0/16`), public subnet, Internet Gateway, and Route Table.
- **Security (`security_groups.tf`)**: Ingress rules tightly restrict traffic to required ports (3000 frontend, 8000 API, 9090 Prometheus, 3001 Grafana, 22 SSH).
- **Compute (`ec2.tf`)**: Provisions an EC2 instance with an Elastic IP and automated `user_data.sh` script that installs Docker, clones the repository, injects environment variables, and launches the stack with Docker Compose.
- **IAM & Access (`iam.tf`)**: Attaches an `AmazonSSMManagedInstanceCore` role so engineers can securely access instances through AWS Systems Manager without opening SSH keys or bastion hosts.

---

### Q25. Why use AWS Systems Manager (SSM) Session Manager instead of conventional SSH key pairs?

**Answer:**
SSM Session Manager provides enterprise-grade security advantages:
- **No Inbound Ports Needed**: Port 22 does not need to be exposed to the public internet in the security group.
- **No Key Management**: Eliminates the risk of lost, shared, or leaked `.pem` private keys.
- **IAM Access Control & Audit Trails**: Access is governed by AWS IAM policies, and every session and command execution can be logged to AWS CloudWatch and S3 for compliance.

