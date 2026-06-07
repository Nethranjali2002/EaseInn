git add -u
git commit -m "chore: Remove old project structure"

git add backend/package.json backend/package-lock.json backend/src/server.js backend/src/app.js
git commit -m "chore(backend): Add backend setup and configuration files"

git add backend/src/models/
git commit -m "feat(backend): Add database schemas and models"

git add backend/src/controllers/
git commit -m "feat(backend): Implement API controllers"

git add backend/src/services/ backend/src/routes/
git commit -m "feat(backend): Add business logic services and API routes"

git add backend/src/utils/ backend/src/middlewares/ backend/src/validators/ backend/src/config/
git commit -m "chore(backend): Add middlewares, validators, and utilities"

git add frontend/shared/
git commit -m "feat(frontend): Create shared logic and providers package"

git add frontend/web/lib/features/web/screens/
git commit -m "feat(frontend/web): Implement admin dashboard screens"

git add frontend/web/lib/features/web/widgets/ frontend/web/lib/core/ frontend/web/lib/main.dart
git commit -m "feat(frontend/web): Add reusable widgets and core routing"

git add frontend/web/
git commit -m "chore(frontend/web): Add flutter web platform configurations"

git add frontend/mobile/
git commit -m "feat(frontend/mobile): Add mobile app implementation"

git add docs/ README.md
git commit -m "docs: Update project documentation and README"

git add .
git commit -m "chore: Final project adjustments and cleanup"

git push origin HEAD
