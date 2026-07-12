# Pre-Commit Checklist

> Run through this checklist before EVERY commit. If any item fails, fix before committing.

## Evidence Verification

- [ ] Every score/claim has a confidence value (0-100)
- [ ] Every claim cites a verifiable source URL
- [ ] No fabricated company data, funding rounds, or team members
- [ ] If data is unavailable, marked as null/0 confidence, never hallucinated
- [ ] Source URLs resolve (tested where possible)

## Code Quality

- [ ] No invented APIs (every endpoint called exists in docs)
- [ ] No invented DB fields (every column matches sql/schema.sql)
- [ ] SQL is idempotent (IF NOT EXISTS, CREATE OR REPLACE)
- [ ] No DROP statements unless explicitly called for
- [ ] Naming conventions followed (snake_case, is_ prefix, _at suffix)
- [ ] All functions/views have COMMENT ON

## Testing

- [ ] SQL functions tested with sample inputs (SELECT function(...))
- [ ] Views return expected columns and data
- [ ] Seed data loads without errors
- [ ] No regression in existing tests
- [ ] Edge cases handled (NULLs, empty JSONB, score boundaries)

## Cost Optimization

- [ ] Cheapest capable model used for the task
- [ ] DeepSeek V4 Flash for high-volume tasks
- [ ] MiMo V2.5 for mid-complexity reasoning
- [ ] Claude Sonnet 4 ONLY for Judge layer (final 20-30 leads)
- [ ] Firecrawl used before Apify (free before paid)

## Database Integrity

- [ ] FK constraints respected (no orphaned references)
- [ ] CHECK constraints valid (score ranges, state values, enum values)
- [ ] Indexes appropriate (no missing FK indexes, no over-indexing)
- [ ] RLS policies present on all tables
- [ ] Timestamptz used (not timestamp or timetz)

## Documentation

- [ ] ADR updated if architectural decision changed
- [ ] CHANGELOG.md updated if user-facing or structural change
- [ ] COMMENT ON added for new tables/columns/functions/views
- [ ] JSONB structure documented in column comment

## Final Verifications

- [ ] `git status` shows only intended files
- [ ] No secrets committed (API keys, tokens, passwords)
- [ ] No commented-out code (unless explicitly temporary)
- [ ] No TODO or FIXME that blocks functionality
- [ ] Build/run succeeds (no syntax errors)
