# SoulBuddy ChatGPT: Privacy and Terms draft

**INTERNAL DRAFT — DO NOT PUBLISH OR LINK IN PLUGIN MANIFEST**

This is working copy grounded in the repository implementation. It is deliberately not legal advice, has not been approved by the service operator, and is missing verified operator/contact, infrastructure, retention and jurisdiction details. Use the [evidence checklist](./chatgpt-release-review.md) before publication.

## Draft Privacy Notice

**Effective date:** [operator to approve]  
**Who operates SoulBuddy:** [verified legal entity / name and contact]  
**Privacy requests:** [verified reachable email or support portal]

### What the service does

SoulBuddy helps people organize personal spiritual and daily-life commitments. The connected ChatGPT life planner helps you propose, save and review a seven-day plan with your permission. It is not a measure of holiness, and you do not need to connect ChatGPT to use SoulBuddy's local-first features.

### Information processed

SoulBuddy's mobile app can hold locally created goals, reflections, prayers and related information. Optional synchronization sends supported account and user records to the SoulBuddy service.

When you connect SoulBuddy to ChatGPT, an identity provider authenticates your session. SoulBuddy checks the token's signature, issuer, subject, audience, scopes, expiry and current activity with the provider. For authorized users, it stores a persistent link between the identity provider's issuer/subject and the SoulBuddy account. Verified email is used when you choose to create or explicitly link an account; matching emails alone do not grant access to existing private records.

With approval, the ChatGPT life planner stores a plan, commitments, reported daily progress, optional brief notes and weekly reflections. Such information may reveal religious beliefs or personal circumstances. We do not need intimate confessions or information about unrelated people to help you form a plan.

Existing SoulBuddy users may request a random 128-bit account-linking code from an authenticated, verified account. The server stores its hash; each code expires after ten minutes and cannot be reused. Expired hashes are scheduled for deletion daily. The app shows the code temporarily and hides it on backgrounding. Copying it is your choice and may place it on the device clipboard.

### Connected services

ChatGPT may process the tool requests and results you choose to use, under your ChatGPT account and settings. Your chosen OAuth identity provider processes authentication and token-status checks. Optional SoulBuddy services may also use PowerSync for cloud synchronization, Firebase for notifications or Deepgram for consented narration, when enabled. [Verify actual vendor contracts, destinations, jurisdictions and provider list before publication.]

ChatGPT scheduled reminders are optional and run through ChatGPT's scheduling and notification controls. SoulBuddy does not create reminder tasks when you merely connect the plugin.

### Choices, access and deletion

You can review your own life plans and history in ChatGPT. You can approve changes to commitments and check-ins and delete a selected life plan; deleting a plan also removes its associated commitments, notes and review from active life-planner tables. Archived plans remain available until individually deleted.

You may unlink your SoulBuddy account from the mobile Settings controls. This stops the former OAuth identity from accessing that SoulBuddy account through the linked tools, but it does not terminate an identity-provider session or remove a ChatGPT-side app connection. Use the controls of both services separately. [Operator must document complete account deletion, backup retention, data export and support handling before publication.]

### Storage, retention and security

The application uses authenticated API boundaries and owner-scoped records. OAuth access tokens are checked against the provider on protected requests. [Operator must specify verified production hosting location, access controls, logging, backup/restore policies, retention periods and any cross-border transfers before publication.] No claim about model training or marketing use should be published without verified operational evidence.

### Questions and privacy requests

Contact [verified support/privacy contact]. [Add correct data-rights, children/minors, complaint channel, lawful basis and jurisdiction disclosures after operator/legal review.]

---

## Draft Terms of Use

**Effective date:** [operator to approve]  
**Provider of service:** [verified legal operator]

### Purpose

SoulBuddy offers Christian formation, personal organization and optional ChatGPT-connected seven-day planning. Its suggestions support your decisions; it does not speak for God, provide authoritative pastoral advice, grade spiritual worth, or replace professional medical, psychological, legal or financial care.

### Accounts and consent

You choose whether to connect a ChatGPT identity and whether to save a plan or reflection. Linking an existing SoulBuddy account requires independent proof of control and an explicit approval. Keep any one-time code private. You are responsible for reviewing and correcting suggested commitments before saving them.

### Availability and external services

ChatGPT, identity providers, hosting and optional notification integrations have separate terms, eligibility requirements and service availability. Connecting an app does not guarantee any notification, task, account-linking outcome or model response. Disconnecting in ChatGPT may not revoke an identity provider's outstanding token; use the provider's separate controls as indicated in the app.

### Personal information and content

Do not enter another person's sensitive private details or intimate confessions unless you have a legitimate reason and the relevant permissions. Plan records can be read and deleted through the authorized tools. See the approved Privacy Notice once published. [Complete ownership/license, data portability, termination, acceptable-use, complaint, legal governing law and liability terms with operator review.]

### Pricing

The SoulBuddy life-planning integration described in this draft does not implement digital checkout or an in-ChatGPT subscription. Do not advertise a paid entitlement until a separate approved offering and current platform rules support it.

### Support

For account, privacy or access questions, contact [verified operator-controlled support channel]. [Publish only when support is tested and monitored.]

---

## Publication acceptance

- [ ] Confirm and insert operator's full legal identity and verified support/privacy contact.
- [ ] Verify production data hosting, processors, logs, backups, account deletion/export and region-specific requirements.
- [ ] Obtain legal/operator approval of the notice and terms; set effective date and version.
- [ ] Publish actual HTTPS policy, terms and support destinations and test them from mobile and ChatGPT.
- [ ] Insert those verified URLs into plugin submission metadata. Never publish a placeholder.
