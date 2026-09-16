# nutrition-tracker-app

A simple full-stack nutrition tracker. Log the foods you eat and keep an eye on
your daily calories and macronutrients (protein, carbs, fat).

## Tech stack

- [Next.js 15](https://nextjs.org/) (App Router) with React 19 and TypeScript
- [Tailwind CSS v4](https://tailwindcss.com/) for styling
- [Prisma ORM](https://www.prisma.io/) backed by a local SQLite database

The app is fully self-contained: the database is a local SQLite file, so no
external services, accounts, or secrets are required to run it.

## Getting started

Requires Node.js 22+.

```bash
# 1. Install dependencies (also generates the Prisma client)
npm install

# 2. Create the database and apply migrations, then load sample data
npx prisma migrate deploy
npx prisma db seed

# 3. Start the dev server
npm run dev
```

Open http://localhost:3000 to use the tracker.

## Scripts

| Command | Description |
| --- | --- |
| `npm run dev` | Start the Next.js dev server on port 3000 |
| `npm run build` | Create an optimized production build |
| `npm start` | Run the production build |
| `npm run lint` | Lint with ESLint (`next lint`) |
| `npm run typecheck` | Type-check with `tsc --noEmit` |
| `npm run db:deploy` | Apply Prisma migrations (`prisma migrate deploy`) |
| `npm run db:seed` | Seed sample food entries |

## API

| Method | Route | Description |
| --- | --- | --- |
| `GET` | `/api/entries` | List all food entries (newest first) |
| `POST` | `/api/entries` | Create a food entry |
| `DELETE` | `/api/entries/:id` | Delete a food entry |
| `GET` | `/api/health` | Health check (verifies the database connection) |

## Data model

A single `FoodEntry` table (see `prisma/schema.prisma`) stores each logged food
with its meal, calories, and macros. Migrations live in `prisma/migrations`.

## Cloud Agent environment

`.cursor/environment.json` defines the Cloud Agent development environment: it
installs dependencies, applies migrations, seeds sample data, and runs the dev
server on port 3000.
