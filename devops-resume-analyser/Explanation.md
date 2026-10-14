"Hello! My project is the DevOps Resume Analyzer. It’s an application that takes a user's resume, parses the text, and uses Groq AI to calculate an ATS score and suggest improvements.

While the app itself is built with a Next.js frontend and a Python FastAPI backend, the core focus of this project is the DevOps pipeline.

Here is how the pipeline flows:

First, I use Terraform to automatically provision the local infrastructure, including Docker networks and servers.
When code is pushed to GitHub, it triggers a Jenkins CI/CD pipeline.
Jenkins runs SonarQube to scan the code for bugs and quality issues. If the code is bad, the pipeline fails.
If it passes, Jenkins uses Docker Compose to build and spin up the frontend and backend.
Finally, Jenkins launches a temporary container to run automated UI tests using Selenium in a headless browser. If the tests pass, the webapp containers are left running so the new version is live, serving as a Continuous Deployment (CD) process.
In short, it’s a full-stack AI application wrapped in a complete, automated DevOps lifecycle."

🤔 Expected Questions from Your Guide (And How to Answer Them)
Q: Why did you use Terraform just for local Docker containers instead of AWS/Cloud?

Answer: "To demonstrate the core concepts of Infrastructure as Code (IaC) without incurring cloud costs. The Terraform state and resource blocks I wrote for Docker translate very easily to AWS ECS or Kubernetes if we scale up."
Q: What is the purpose of the 'Quality Gate' in Jenkins?

Answer: "The Quality Gate prevents bad code from being deployed. SonarQube analyzes the code, and if it has too many vulnerabilities, code smells, or low test coverage, it tells Jenkins to abort the build before Docker even starts."
Q: Why did you run Selenium in 'Headless' mode?

Answer: "Because Jenkins runs in the background on a server (or inside a Docker container) where there is no physical monitor to open a browser window. Headless mode allows Chrome to run and test the UI purely in memory."
Q: Why use Groq API instead of OpenAI?

Answer: "Groq uses specialized hardware (LPUs) that makes token generation incredibly fast. Since resume analysis requires processing a lot of text, Groq provides a much faster and smoother user experience."