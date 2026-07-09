# ImportPulse — Idempotent CSV Imports with Live Progress

A focused Rails demo of one production problem done properly: **bulk CSV imports
processed by Sidekiq, safe under retries, with progress streamed live to the
browser via Turbo Streams** — no JavaScript framework, no polling.

Upload a CSV of contacts. The file is fanned out into batched background jobs.
A progress bar and per-row error table update in real time as workers chew
through the rows.

## The Problem

Naive import implementations break in production in two predictable ways:

1. **Duplicates on retry.** Sidekiq (like every serious job system) is
   *at-least-once*: a worker can die after writing rows but before
   acknowledging the job, and the job will run again. If the job does plain
   `INSERT`s, every retry duplicates data. If you disable retries to avoid
   that, you lose rows instead.
2. **Lying progress counters.** If jobs report progress by incrementing a
   counter (`processed_rows += 100`), a retried job double-counts and your
   progress bar says 120%.

ImportPulse treats both as design constraints, not edge cases.

## How It Works

```
POST /imports
     │
     ▼
ImportDispatchJob            counts rows, records total,
     │                       enqueues one job per batch
     ├──────────────┬──────────────┐
     ▼              ▼              ▼
ImportBatchJob  ImportBatchJob  ImportBatchJob     (batch_number 0, 1, 2…)
     │              │              │
     │  parse own CSV slice → upsert rows & errors
     │  recompute progress from DB → broadcast via Turbo Streams
     ▼              ▼              ▼
┌────────────────────────────────────────────┐
│  imports/:id  — progress bar + error table │
│  updates live over ActionCable (Redis)     │
└────────────────────────────────────────────┘
```

## Design Decisions

**Idempotency via a natural key, enforced by the database.**
Every persisted row — success or failure — carries `(import_id, row_number)`
under a unique index, and jobs write with `upsert_all(unique_by:)`. A retried
batch re-writes the same rows instead of duplicating them. The guarantee lives
in the schema, not in application discipline.

**Derive state, don't accumulate it.**
Progress counters are recomputed from `COUNT(*)` after each batch
(`Import#refresh_progress!`), never incremented. A batch that runs three times
produces exactly the same progress as one that runs once. The completion check
runs under a row lock so two batches finishing simultaneously can't both miss
the finish line.

**Self-contained jobs.**
A batch job's arguments are two integers: `(import_id, batch_number)`. It
re-reads its own slice of the CSV from disk. Nothing perishable is serialized
into Redis, which keeps retries cheap and arguments debuggable in the Sidekiq
UI.

**Errors are data, not exceptions.**
A malformed row doesn't abort its batch or trigger a retry — it becomes an
`ImportError` record (with the raw row for debugging), upserted with the same
idempotency key, streamed to the UI, and counted as progress. Retries are
reserved for infrastructure failures, where they belong.

**Server-rendered real-time UI.**
The progress bar and error table are plain ERB partials broadcast over
Turbo Streams. The entire frontend JavaScript is one line
(`import "@hotwired/turbo-rails"`).

## Stack

Ruby on Rails 7.1 · PostgreSQL · Sidekiq 7 (Redis) · Hotwire (Turbo Streams) ·
RSpec + FactoryBot

## Running It

Prerequisites: Ruby 3.1+, Docker (for Postgres + Redis).

```bash
docker compose up -d        # Postgres :5432, Redis :6379
bin/setup                   # bundle install + db:prepare
foreman start -f Procfile.dev   # web :3000 + sidekiq worker
```

Visit http://localhost:3000, upload a CSV with `name,email` columns, and watch
the pipeline run. The Sidekiq dashboard is mounted at `/sidekiq` in
development.

A quick way to generate a test file:

```bash
ruby -e 'puts "name,email"; 1.upto(1000) { |i| puts "Person #{i},person#{i}@example.com" }' > /tmp/contacts.csv
```

Add a few broken rows (missing names, bad emails) to see error streaming.

## Tests

```bash
bundle exec rspec
```

The suite is the point of the repo. Highlights:

- **`spec/sidekiq/import_batch_job_spec.rb`** — proves idempotency by running
  the same batch job multiple times and asserting identical row counts and
  progress; proves malformed rows are recorded once, not duplicated, across
  retries.
- **`spec/sidekiq/import_dispatch_job_spec.rb`** — verifies the fan-out math
  and that finished imports are never reprocessed.
- **`spec/models/import_spec.rb`** — shows progress is *derived*: even a
  corrupted counter self-heals on the next refresh.

## What This Deliberately Isn't

No authentication, no multi-tenancy, no file-type sniffing beyond the
extension, no S3. Those belong in a product; this repo isolates one hard
problem — **correct background processing under at-least-once delivery** — so
the interesting decisions aren't buried under CRUD.

## License

MIT
