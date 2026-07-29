# Ensure Edition Deliveries

## Problem

Some scheduled editions predate per-channel `Delivery` rows. Missing deliveries leave publish with nothing to enqueue. Today, inapplicable Meta channels are omitted (or destroyed at job time), so absence is ambiguous: never created vs intentionally not sent.

## Goals

1. Every scheduled edition has a `Delivery` row for each channel in `Delivery::CHANNELS`.
2. Absence of a row means “never ensured” and should be created.
3. `skipped` means “do not send” (not applicable at create time, or manually skipped).
4. A single job both creates rows at approve time and backfills gaps on a schedule.

## Non-goals

- Re-evaluating or flipping existing `pending` ↔ `skipped` statuses (manual skips must stick).
- Backfilling published/failed editions (only scheduled + Approver path).
- Admin UI for manual skip (status support only).

## Design

### Status model

`Delivery::STATUSES` becomes `%w[pending succeeded failed skipped]`.

| Status | Meaning |
|--------|---------|
| *(no row)* | Never created — ensure job should add it |
| `pending` | Should send at publish |
| `skipped` | Do not send |
| `succeeded` / `failed` | Terminal after attempt |

### `EnsureEditionDeliveriesJob`

- `perform(edition_id)` — ensure one edition (Approver uses `perform_now`).
- `perform` with no args — ensure every `Edition.scheduled` (recurring schedule uses `perform_later`).
- For each channel in `Delivery::CHANNELS`: if no row exists, create with `pending` if `applicable?`, else `skipped`.
- Never update existing delivery statuses.

### Approver

After creating or updating the scheduled edition, call `EnsureEditionDeliveriesJob.perform_now(edition.id)`. Remove inline `deliveries.create!` loops.

### Publish / finalize / skip path

- `PublishEditionJob` enqueues only `pending` deliveries.
- `Edition#deliveries_terminal?` treats `skipped` as terminal (with `succeeded` / `failed`).
- `DeliveryJob#skip_delivery!` sets `skipped` instead of `destroy!`.

### Schedule

In `config/recurring.yml` (development + production):

```yaml
ensure_edition_deliveries:
  class: EnsureEditionDeliveriesJob
  queue: default
  schedule: at 6am every day
```

Runs one hour before `PublishEditionJob` (7am).

## Testing

- Job: creates missing channels with correct status; leaves existing statuses alone; batch mode covers all scheduled.
- Approver: always ends with five channels; inapplicable Meta are `skipped`.
- Publish: does not enqueue `skipped`.
- DeliveryJob: inapplicable → `skipped` row remains.
- `deliveries_terminal?`: true when remaining channels are `skipped`.
