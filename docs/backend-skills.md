# Backend Agent Directives: Node.js & MongoDB (EnergyoSense)

## 1. Core Operating Rules (Strict Token Optimization)
* **Code-Only Output:** Output strictly the requested code, configurations, database schemas, or bash commands.
* **Zero Exposition:** Exclude greetings, conversational filler, summaries, and concluding remarks.
* **Diff Updates:** For existing files, return only the modified modules, functions, or lines. Do not print the entire unchanged file.
* **Explicit Explanations:** Provide explanations, architectural justifications, or line-by-line breakdowns **ONLY** if the user appends the `--explain` flag.

## 2. Technical Context & Environment
* **Assumed Expertise:** Expert Backend Developer and DevSecOps Engineer.
* **Core Stack:** Node.js, Express.js, MongoDB (Mongoose ORM).
* **Architecture:** Controller-Service-Route separation pattern.
* **Infrastructure:** Linux VPS (Rocky/Ubuntu) and Dockerized deployment environments.
* **CI/CD Automation:** Focus on lightweight automation using custom deployment webhooks (Bash/Python). Do not suggest heavy enterprise orchestration tools.

## 3. Backend Coding Standards
* **Modern Syntax:** Utilize ES6+ syntax exclusively (async/await, destructuring, modules). No callbacks.
* **Error Handling:** Implement centralized error-handling middleware. Ensure no unhandled promise rejections.
* **Standardized Responses:** Use consistent API response structures across all controllers.
* **Configuration:** Always reference environment variables for secrets, ports, and database URIs. Never hardcode sensitive data.

## 4. DevSecOps & Security Baselines
* **Authentication/Authorization:** Implement secure, stateless JWT authentication and robust middleware for role-based route protection.
* **Validation:** Apply strict input validation and sanitization to mitigate NoSQL injection and payload manipulation.
* **API Protection:** Default to secure configurations, including appropriate CORS policies, Helmet for secure HTTP headers, and rate-limiting for public endpoints.
* **Infrastructure Security:** Ensure generated Dockerfiles and VPS configuration commands adhere to the principle of least privilege (e.g., running Node as a non-root user).

## 5. Formatting Standards
* Provide production-ready, flawlessly formatted code ready for direct insertion.
* Omit standard inline comments unless documenting complex regex, cryptographic implementations, or non-standard security configurations.

## 6. Dynamic Scope & Feature Management
* **Proactive Feature Tracking:** If a new requirement is explicitly requested, or if a standard necessary feature (e.g., specific DevSecOps auditing, data pagination, or missing CRUD operations) is logically required for the EnergyoSense architecture, immediately flag it.
* **Checklist Updates:** Output the exact modified line or markdown task (e.g., `- [ ] Implement pagination for user logs`) required to update the `checklists.md` file without asking for permission, strictly adhering to the Code-Only Output rule.