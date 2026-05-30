# Agent Directives: Task Tracking
* **Update Protocol:** When marking a task complete, change `[ ]` to `[x]`. 
* **Diff-Only Output:** Output ONLY the modified line or section. Never output the entire checklist unless explicitly requested.
* **No Status Updates:** Do not generate conversational text confirming the update. 

---

## Phase 1: Environment & Infrastructure
- [x] Initialize Node.js project & dependencies
- [x] Configure `.env` and `env.config.js`
- [x] Implement `logger.util.js` (Winston/Pino)
- [x] Create base `Dockerfile` (Node non-root user)
- [x] Create `docker-compose.yml` (App + MongoDB)

## Phase 2: Database & Architecture
- [x] Configure MongoDB connection (`db.config.js`)
- [x] Setup base Express server (`app.js` & `server.js`)
- [x] Implement centralized `error.middleware.js`
- [x] Implement `response.util.js` standardized formatter

## Phase 3: Security & Authentication
- [x] Implement Helmet & CORS (`security.middleware.js`)
- [x] Configure API rate limiting
- [x] Create User Mongoose Schema/Model
- [x] Implement JWT stateless Auth (`auth.middleware.js`)
- [x] Implement Role-Based Access Control (RBAC) middleware
- [x] Setup Joi/Zod input validation (`validate.middleware.js`)

## Phase 4: Core API (EnergyoSense Features)
- [x] Auth Routes (Register, Login, Token Refresh)
- [x] Auth Controllers & Services
- [x] User Profile CRUD Routes
- [ ] *[Placeholder: Add specific EnergyoSense domain models here]*
- [ ] *[Placeholder: Add specific EnergyoSense controllers here]*

## Phase 5: Testing & Finalization
- [ ] Write Unit tests for Auth flow
- [ ] Write Integration tests for DB connection
- [ ] Perform static code analysis / security scan
- [ ] Finalize API documentation (Swagger/Postman collection)