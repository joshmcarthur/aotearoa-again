# Ensure Edition Deliveries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `skipped` delivery status and an `EnsureEditionDeliveriesJob` that Approver runs sync and a 6am schedule runs async, so every scheduled edition has a full channel set without destroying intentional skips.

**Architecture:** One job creates missing `Delivery` rows (`pending` if applicable, else `skipped`) and never mutates existing statuses. Approver calls `perform_now`; recurring.yml enqueues the batch at 6am. Publish only enqueues `pending`; terminal includes `skipped`; DeliveryJob marks `skipped` instead of destroy.

**Tech Stack:** Rails 8, Solid Queue recurring tasks, Minitest, ActiveJob::TestHelper

## Global Constraints

- Never update existing delivery statuses in the ensure job (manual skips stick).
- Only create missing channels; full set is always `Delivery::CHANNELS`.
- Absence of a row means never created; `skipped` means do not send.
- Do not commit unless the user asks (user rule).

---

### Task 1: `skipped` status + terminal + DeliveryJob skip

**Files:**
- Modify: `app/models/delivery.rb`
- Modify: `app/models/edition.rb`
- Modify: `app/jobs/delivery_job.rb`
- Modify: `test/models/edition_test.rb`
- Modify: `test/jobs/delivery_jobs_test.rb`

**Interfaces:**
- Produces: `Delivery::STATUSES` includes `"skipped"`; `Edition#deliveries_terminal?` treats skipped as terminal; `DeliveryJob#skip_delivery!` updates to skipped

- [ ] **Step 1: Update failing expectations for skip / terminal**

In `test/models/edition_test.rb`, extend `deliveries_terminal?` test so a `skipped` delivery counts as terminal.

In `test/jobs/delivery_jobs_test.rb`, change `"skips inapplicable meta channels"` to assert Meta deliveries exist with status `"skipped"` (not `nil`).

- [ ] **Step 2: Run tests — expect fail**

Run: `bin/rails test test/models/edition_test.rb test/jobs/delivery_jobs_test.rb -n "/terminal|skips inapplicable/"`

- [ ] **Step 3: Implement status + skip + terminal**

```ruby
# delivery.rb
STATUSES = %w[pending succeeded failed skipped].freeze

# edition.rb
def deliveries_terminal?
  deliveries.reload.all? { |d| d.status.in?(%w[succeeded failed skipped]) }
end

# delivery_job.rb
def skip_delivery!(delivery)
  return if delivery.status.in?(%w[succeeded skipped])

  delivery.update!(status: "skipped")
end
```

Also early-return in `perform` if `delivery.status == "skipped"` before applicability check (optional but clear).

- [ ] **Step 4: Run tests — expect pass**

---

### Task 2: `EnsureEditionDeliveriesJob`

**Files:**
- Create: `app/jobs/ensure_edition_deliveries_job.rb`
- Create: `test/jobs/ensure_edition_deliveries_job_test.rb`

**Interfaces:**
- Consumes: `Delivery::CHANNELS`, `Delivery#applicable?`, `Edition.scheduled`
- Produces: `EnsureEditionDeliveriesJob#perform(edition_id = nil)`

- [ ] **Step 1: Write job tests**

Cover: single edition creates all channels with pending/skipped via applicable?; does not change existing skipped/pending; batch mode with no args processes all scheduled.

- [ ] **Step 2: Run test — expect fail (job missing)**

- [ ] **Step 3: Implement job**

```ruby
class EnsureEditionDeliveriesJob < ApplicationJob
  queue_as :default

  def perform(edition_id = nil)
    if edition_id
      ensure_for(Edition.find(edition_id))
    else
      Edition.scheduled.find_each { |edition| ensure_for(edition) }
    end
  end

  private

  def ensure_for(edition)
    Delivery::CHANNELS.each do |channel|
      delivery = edition.deliveries.find_or_initialize_by(channel: channel)
      next unless delivery.new_record?

      delivery.status = delivery.applicable? ? "pending" : "skipped"
      delivery.save!
    end
  end
end
```

- [ ] **Step 4: Run tests — expect pass**

---

### Task 3: Wire Approver + PublishEditionJob + recurring schedule

**Files:**
- Modify: `app/services/editions/approver.rb`
- Modify: `app/jobs/publish_edition_job.rb`
- Modify: `config/recurring.yml`
- Modify: `test/models/edition_test.rb` (approver expectations)
- Modify: `test/jobs/publish_edition_job_test.rb`

**Interfaces:**
- Consumes: `EnsureEditionDeliveriesJob.perform_now(edition.id)`
- Produces: Approver always leaves five deliveries; publish enqueues only pending

- [ ] **Step 1: Update Approver / publish tests**

Approver “omits meta” tests → assert Meta channels present with `"skipped"`. Configured Meta → all `"pending"`. Publish test: skipped delivery is not enqueued.

- [ ] **Step 2: Run — expect fail**

- [ ] **Step 3: Implement wiring**

Approver: replace create loops with `EnsureEditionDeliveriesJob.perform_now(edition.id)` (both new and existing edition paths).

PublishEditionJob: `edition.deliveries.where(status: "pending").each(&:enqueue!)`

recurring.yml (development + production):

```yaml
ensure_edition_deliveries:
  class: EnsureEditionDeliveriesJob
  queue: default
  schedule: at 6am every day
```

- [ ] **Step 4: Run full related suite**

Run: `bin/rails test test/models/edition_test.rb test/models/delivery_test.rb test/jobs/ensure_edition_deliveries_job_test.rb test/jobs/publish_edition_job_test.rb test/jobs/delivery_jobs_test.rb test/jobs/finalize_edition_publish_job_test.rb`
